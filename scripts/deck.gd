class_name BurracoDeck
extends RefCounted

const BurracoCardData = preload("res://scripts/card_data.gd")


var stock_pile: Array[BurracoCardData] = []
var discard_pile: Array[BurracoCardData] = []
var pozzetto_player: Array[BurracoCardData] = []
var pozzetto_opponent: Array[BurracoCardData] = []

func initialize_and_deal(player_hand: Array[BurracoCardData], opponent_hand: Array[BurracoCardData]) -> void:
    var full_deck: Array[BurracoCardData] = []
    var card_id: int = 1

    # 2 mazzi standard da 52 carte + 2 Jolly ciascuno = 108 carte
    for d in range(2):
        for s in [BurracoCardData.Suit.HEARTS, BurracoCardData.Suit.DIAMONDS, BurracoCardData.Suit.CLUBS, BurracoCardData.Suit.SPADES]:
            for r in range(1, 14):
                full_deck.append(BurracoCardData.create_card(card_id, s, r as BurracoCardData.Rank, d))
                card_id += 1
        # 2 Jolly per mazzo
        full_deck.append(BurracoCardData.create_card(card_id, BurracoCardData.Suit.JOKER, BurracoCardData.Rank.JOKER, d, true))
        card_id += 1
        full_deck.append(BurracoCardData.create_card(card_id, BurracoCardData.Suit.JOKER, BurracoCardData.Rank.JOKER, d, true))
        card_id += 1

    full_deck.shuffle()

    # 1. Pozzetto Giocatore (11 carte)
    pozzetto_player.clear()
    for i in range(11): pozzetto_player.append(full_deck.pop_back())

    # 2. Pozzetto Avversario (11 carte)
    pozzetto_opponent.clear()
    for i in range(11): pozzetto_opponent.append(full_deck.pop_back())

    # 3. Mano Giocatore (11 carte)
    player_hand.clear()
    for i in range(11): player_hand.append(full_deck.pop_back())

    # 4. Mano Avversario (11 carte)
    opponent_hand.clear()
    for i in range(11): opponent_hand.append(full_deck.pop_back())

    # 5. Prima carta monte scarti
    discard_pile.clear()
    discard_pile.append(full_deck.pop_back())

    # 6. Tallone
    stock_pile = full_deck

func draw_from_stock() -> BurracoCardData:
    if stock_pile.is_empty(): return null
    return stock_pile.pop_back()

func take_entire_discard_pile() -> Array[BurracoCardData]:
    var taken: Array[BurracoCardData] = discard_pile.duplicate()
    discard_pile.clear()
    return taken

func discard(card: BurracoCardData) -> void:
    if card != null:
        discard_pile.append(card)

func peek_top_discard() -> BurracoCardData:
    if discard_pile.is_empty(): return null
    return discard_pile.back()

func take_player_pozzetto() -> Array[BurracoCardData]:
    var p = pozzetto_player.duplicate()
    pozzetto_player.clear()
    return p

func take_opponent_pozzetto() -> Array[BurracoCardData]:
    var p = pozzetto_opponent.duplicate()
    pozzetto_opponent.clear()
    return p
