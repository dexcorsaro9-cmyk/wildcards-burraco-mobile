class_name BurracoCardData
extends Resource

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES, JOKER }
enum Rank {
    NONE = 0,
    ACE = 1,
    TWO = 2,
    THREE = 3,
    FOUR = 4,
    FIVE = 5,
    SIX = 6,
    SEVEN = 7,
    EIGHT = 8,
    NINE = 9,
    TEN = 10,
    JACK = 11,
    QUEEN = 12,
    KING = 13,
    JOKER = 14
}

@export var id: int = 0
@export var suit: Suit = Suit.HEARTS
@export var rank: Rank = Rank.ACE
@export var deck_index: int = 0
@export var is_joker: bool = false
@export var creature_name: String = ""
@export var creature_rarity: String = "Common"

func is_pinella() -> bool:
    return rank == Rank.TWO and not is_joker

func is_wildcard() -> bool:
    return is_joker or is_pinella()

func get_point_value() -> int:
    if is_joker: return 30
    if is_pinella(): return 20
    if rank == Rank.ACE: return 15
    if rank >= Rank.EIGHT and rank <= Rank.KING: return 10
    return 5

func get_rank_string() -> String:
    if is_joker: return "JK"
    match rank:
        Rank.ACE: return "A"
        Rank.TWO: return "2"
        Rank.THREE: return "3"
        Rank.FOUR: return "4"
        Rank.FIVE: return "5"
        Rank.SIX: return "6"
        Rank.SEVEN: return "7"
        Rank.EIGHT: return "8"
        Rank.NINE: return "9"
        Rank.TEN: return "10"
        Rank.JACK: return "J"
        Rank.QUEEN: return "Q"
        Rank.KING: return "K"
        _: return "?"

func get_suit_symbol() -> String:
    match suit:
        Suit.HEARTS: return "♥"
        Suit.DIAMONDS: return "♦"
        Suit.CLUBS: return "♣"
        Suit.SPADES: return "♠"
        _: return "★"

func get_suit_color() -> Color:
    if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
        return Color(0.88, 0.18, 0.18)
    return Color(0.12, 0.12, 0.15)

static func create_card(p_id: int, p_suit: Suit, p_rank: Rank, p_deck: int = 0, p_joker: bool = false) :
    var c = load("res://scripts/card_data.gd").new()
    c.id = p_id
    c.suit = p_suit
    c.rank = p_rank
    c.deck_index = p_deck
    c.is_joker = p_joker
    c.creature_name = get_default_creature(p_rank, p_suit, p_joker)
    c.creature_rarity = get_default_rarity(p_rank, p_joker)
    return c

static func get_default_creature(r: Rank, s: Suit, joker: bool) -> String:
    if joker: return "Neon Chimera"
    if r == Rank.TWO: return "Cyber Pinella"
    if r == Rank.ACE: return "Solar Sphinx"
    if r == Rank.KING: return "Apex Dragon"
    if r == Rank.QUEEN: return "Mystic Empress"
    if r == Rank.JACK: return "Rogue Golem"
    return "Elemental " + ["Hearts", "Diamonds", "Clubs", "Spades", "Joker"][s]

static func get_default_rarity(r: Rank, joker: bool) -> String:
    if joker: return "Legendary"
    if r == Rank.TWO: return "Legendary"
    if r == Rank.KING or r == Rank.QUEEN or r == Rank.JACK: return "Epic"
    if r == Rank.ACE or r == Rank.FIVE: return "Rare"
    return "Common"

func get_wild_trait_title() -> String:
    if is_joker: return "★ MUTA-CHIMERA"
    if is_pinella(): return "🐲 DRAGHETTO PINELLA"
    match rank:
        Rank.ACE: return "🗡️ LANCIA CELESTE"
        Rank.FIVE: return "🛡️ SCUDO PALADINO"
        Rank.JACK: return "⚔️ CAVALIERE IMPAVIDO"
        Rank.QUEEN: return "🔮 OCCHIO INCANTATRICE"
        Rank.KING: return "👑 SOVRANO GUERRIERO"
        _: return ""

func get_wild_trait_desc() -> String:
    if is_joker: return "Wild universale: +50 pt se chiudi con esso."
    if is_pinella(): return "Se calata con il suo seme, Burraco Semipulito (+150 pt). Raddoppia chiusura (+200 pt)!"
    match rank:
        Rank.ACE: return "+20 pt extra se calata all'estremita di una scala."
        Rank.FIVE: return "Quando scartata, congela il monte scarti per 1 turno."
        Rank.JACK: return "Quando calata, ruba 15 fiches all'avversario."
        Rank.QUEEN: return "Quando calata, rivela la prima carta del tallone."
        Rank.KING: return "Se fa parte di un Burraco, assegna +50 pt extra."
        _: return ""

func get_classic_fiches_multiplier() -> float:
    match creature_rarity:
        "Legendary": return 0.50
        "Epic": return 0.25
        "Rare": return 0.10
        _: return 0.0
