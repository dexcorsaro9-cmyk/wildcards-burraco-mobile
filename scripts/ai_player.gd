class_name BurracoAI
extends RefCounted

const BurracoCardData = preload("res://scripts/card_data.gd")
const BurracoRules = preload("res://scripts/rules.gd")


func decide_draw_from_discard(top: BurracoCardData, hand: Array[BurracoCardData], my_melds: Array[BurracoRules.BurracoMeld]) -> bool:
    if top == null: return false
    if top.is_wildcard(): return true

    for m in my_melds:
        if BurracoRules.can_attach_to_meld(m, top): return true

    var close_cards = 0
    for c in hand:
        if c.rank == top.rank or (c.suit == top.suit and abs((c.rank as int) - (top.rank as int)) <= 2):
            close_cards += 1
    return close_cards >= 2

func find_possible_melds(hand: Array[BurracoCardData]) -> Array[Array]:
    var result: Array[Array] = []
    var pool = hand.duplicate()

    # Cerca tris
    var ranks_map = {}
    for c in pool:
        if not c.is_wildcard():
            if not ranks_map.has(c.rank): ranks_map[c.rank] = []
            ranks_map[c.rank].append(c)

    for r in ranks_map:
        if ranks_map[r].size() >= 3:
            var combo: Array[BurracoCardData] = []
            for i in range(min(4, ranks_map[r].size())):
                combo.append(ranks_map[r][i])
            result.append(combo)
            for c in combo: pool.erase(c)

    return result

func choose_discard(hand: Array[BurracoCardData]) -> BurracoCardData:
    if hand.is_empty(): return null
    var non_wilds: Array[BurracoCardData] = []
    for c in hand: if not c.is_wildcard(): non_wilds.append(c)
    if non_wilds.is_empty(): return hand[0]
    return non_wilds.pick_random()
