class_name BurracoRules
extends RefCounted

const BurracoCardData = preload("res://scripts/card_data.gd")


enum MeldType { SEQUENCE, SET }
enum BurracoType { NONE, DIRTY, SEMI_CLEAN, CLEAN }

class BurracoMeld extends RefCounted:
    var id: String = ""
    var type: MeldType = MeldType.SEQUENCE
    var suit: BurracoCardData.Suit = BurracoCardData.Suit.HEARTS
    var rank: BurracoCardData.Rank = BurracoCardData.Rank.ACE
    var cards: Array[BurracoCardData] = []
    var is_player: bool = true

    func get_burraco_type() -> BurracoType:
        if cards.size() < 7: return BurracoType.NONE
        var wild_count = 0
        for c in cards: if c.is_wildcard(): wild_count += 1
        if wild_count == 0: return BurracoType.CLEAN
        if type == MeldType.SEQUENCE and wild_count == 1:
            for c in cards:
                if c.is_pinella() and c.suit == suit:
                    return BurracoType.SEMI_CLEAN
        return BurracoType.DIRTY

    func get_bonus_points() -> int:
        match get_burraco_type():
            BurracoType.CLEAN: return 200
            BurracoType.SEMI_CLEAN: return 150
            BurracoType.DIRTY: return 100
            _: return 0

    func get_total_score(is_wild_mode: bool = false) -> int:
        var s = 0
        for c in cards: s += c.get_point_value()
        var bp = get_bonus_points()
        if is_wild_mode and bp > 0:
            for c in cards:
                if c.rank == BurracoCardData.Rank.KING:
                    bp += 50
                    break
        if is_wild_mode and type == MeldType.SEQUENCE:
            for c in cards:
                if c.rank == BurracoCardData.Rank.ACE:
                    bp += 20
                    break
        s += bp
        return s

static func calculate_player_breakdown(melds: Array, hand: Array, had_pozzetto: bool, is_winner_closer: bool, is_wild_mode: bool) -> Dictionary:
    var cards_points = 0
    var clean_count = 0
    var semi_count = 0
    var dirty_count = 0
    var burraco_points = 0

    for m in melds:
        for c in m.cards:
            cards_points += c.get_point_value()
        var bt = m.get_burraco_type()
        if bt == BurracoType.CLEAN:
            clean_count += 1
            burraco_points += 200
        elif bt == BurracoType.SEMI_CLEAN:
            semi_count += 1
            burraco_points += 150
        elif bt == BurracoType.DIRTY:
            dirty_count += 1
            burraco_points += 100

    var closure_points = 100 if is_winner_closer else 0
    var pozzetto_penalty = 0 if had_pozzetto else -100

    var hand_penalty = 0
    for c in hand:
        hand_penalty -= c.get_point_value()

    var total = cards_points + burraco_points + closure_points + pozzetto_penalty + hand_penalty

    return {
        "cards_points": cards_points,
        "clean_count": clean_count,
        "semi_count": semi_count,
        "dirty_count": dirty_count,
        "burraco_points": burraco_points,
        "closure_points": closure_points,
        "pozzetto_penalty": pozzetto_penalty,
        "hand_penalty": hand_penalty,
        "total": total
    }

static func validate_new_meld(input_cards: Array[BurracoCardData]) -> Dictionary:
    if input_cards.size() < 3:
        return {"valid": false, "error": "Servono almeno 3 carte per una calata."}

    var wild_count = 0
    for c in input_cards: if c.is_wildcard(): wild_count += 1
    if wild_count > 1:
        return {"valid": false, "error": "Non puoi usare più di una matta (Jolly o Pinella)."}

    # Prova come Tris / Set
    var set_res = _try_validate_set(input_cards)
    if set_res.valid:
        return {"valid": true, "type": MeldType.SET, "rank": set_res.rank}

    # Prova come Scala / Sequenza
    var seq_res = _try_validate_sequence(input_cards)
    if seq_res.valid:
        return {"valid": true, "type": MeldType.SEQUENCE, "suit": seq_res.suit}

    return {"valid": false, "error": "La combinazione non è valida né come Scala né come Tris."}

static func _try_validate_set(cards: Array[BurracoCardData]) -> Dictionary:
    var naturals: Array[BurracoCardData] = []
    for c in cards: if not c.is_wildcard(): naturals.append(c)
    if naturals.is_empty(): return {"valid": false}

    var target_rank = naturals[0].rank
    for c in naturals:
        if c.rank != target_rank: return {"valid": false}
    return {"valid": true, "rank": target_rank}

static func _try_validate_sequence(cards: Array[BurracoCardData]) -> Dictionary:
    var naturals: Array[BurracoCardData] = []
    for c in cards: if not c.is_wildcard(): naturals.append(c)
    if naturals.is_empty(): return {"valid": false}

    var target_suit = naturals[0].suit
    for c in naturals:
        if c.suit != target_suit: return {"valid": false}

    var ranks: Array[int] = []
    for c in naturals: ranks.append(c.rank as int)
    ranks.sort()

    # Asso alto se ci sono carte alte
    if ranks.has(1):
        var has_high = false
        for r in ranks: if r >= 10: has_high = true
        if has_high:
            ranks.erase(1)
            ranks.append(14)
            ranks.sort()

    var gaps = 0
    for i in range(ranks.size() - 1):
        var diff = ranks[i + 1] - ranks[i]
        if diff == 0: return {"valid": false} # duplicati non ammessi in sequenza
        gaps += (diff - 1)

    var wilds = cards.size() - naturals.size()
    if gaps <= wilds:
        return {"valid": true, "suit": target_suit}
    return {"valid": false}

static func can_attach_cards_to_meld(meld: BurracoMeld, new_cards: Array[BurracoCardData]) -> bool:
    if new_cards.is_empty(): return false
    var test_cards = meld.cards.duplicate()
    test_cards.append_array(new_cards)
    if meld.type == MeldType.SET:
        var wild_count = 0
        for c in test_cards: if c.is_wildcard(): wild_count += 1
        if wild_count > 1: return false
        var set_res = _try_validate_set(test_cards)
        return set_res.valid
    else:
        var wild_count = 0
        for c in test_cards: if c.is_wildcard(): wild_count += 1
        if wild_count > 1: return false
        var seq_res = _try_validate_sequence(test_cards)
        return seq_res.valid

static func can_attach_to_meld(meld: BurracoMeld, card: BurracoCardData) -> bool:
    if card == null: return false
    return can_attach_cards_to_meld(meld, [card])

static func sort_meld_cards(meld: BurracoMeld) -> void:
    if meld.cards.size() <= 1: return
    if meld.type == MeldType.SET:
        var naturals: Array[BurracoCardData] = []
        var wilds: Array[BurracoCardData] = []
        for c in meld.cards:
            if c.is_wildcard(): wilds.append(c)
            else: naturals.append(c)
        meld.cards.clear()
        meld.cards.append_array(naturals)
        meld.cards.append_array(wilds)
    else:
        var naturals: Array[BurracoCardData] = []
        var wilds: Array[BurracoCardData] = []
        for c in meld.cards:
            if c.is_wildcard(): wilds.append(c)
            else: naturals.append(c)
        if naturals.is_empty(): return

        var has_high = false
        for c in naturals:
            if (c.rank as int) >= 10: has_high = true

        naturals.sort_custom(func(a: BurracoCardData, b: BurracoCardData) -> bool:
            var ra = 14 if (a.rank == BurracoCardData.Rank.ACE and has_high) else (a.rank as int)
            var rb = 14 if (b.rank == BurracoCardData.Rank.ACE and has_high) else (b.rank as int)
            return ra < rb
        )

        if wilds.is_empty():
            meld.cards = naturals
            return

        var wild = wilds[0]
        var res: Array[BurracoCardData] = []
        var inserted = false
        for i in range(naturals.size() - 1):
            res.append(naturals[i])
            var ra = 14 if (naturals[i].rank == BurracoCardData.Rank.ACE and has_high) else (naturals[i].rank as int)
            var rb = 14 if (naturals[i+1].rank == BurracoCardData.Rank.ACE and has_high) else (naturals[i+1].rank as int)
            if rb - ra > 1 and not inserted:
                res.append(wild)
                inserted = true

        res.append(naturals.back())
        if not inserted:
            var lowest = 14 if (naturals.front().rank == BurracoCardData.Rank.ACE and has_high) else (naturals.front().rank as int)
            var highest = 14 if (naturals.back().rank == BurracoCardData.Rank.ACE and has_high) else (naturals.back().rank as int)
            if lowest == 3:
                res.push_front(wild)
            elif highest < 14:
                res.push_back(wild)
            else:
                res.push_front(wild)
        meld.cards = res

