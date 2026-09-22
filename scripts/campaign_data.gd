class_name CampaignVillain
extends Resource

## Un avversario della modalità Storia: chi è, quanto è forte e cosa sblocca.

@export var id: String = ""
@export var display_name: String = ""
@export var epithet: String = ""
@export var flavor_line: String = ""
@export var difficulty: float = 0.5 # 0.0 facile -> 1.0 durissimo, guida l'IA
@export var five_freeze_priority: bool = false # l'IA cerca di scartare il 5 per congelare il monte
@export var extended_freeze: bool = false # il suo Scudo del Paladino dura 2 turni invece di 1
@export var is_boss: bool = false
@export var reward_fiches: int = 50
@export var reward_coins: int = 0
@export var unlock_card_skin: String = "" # id finitura carta sbloccata (solo boss), vuoto = nessuna

static func _make(p_id: String, p_name: String, p_epithet: String, p_flavor: String, p_diff: float, p_five_prio: bool, p_ext_freeze: bool, p_is_boss: bool, p_fiches: int, p_coins: int, p_skin: String) -> CampaignVillain:
    var v = CampaignVillain.new()
    v.id = p_id
    v.display_name = p_name
    v.epithet = p_epithet
    v.flavor_line = p_flavor
    v.difficulty = p_diff
    v.five_freeze_priority = p_five_prio
    v.extended_freeze = p_ext_freeze
    v.is_boss = p_is_boss
    v.reward_fiches = p_fiches
    v.reward_coins = p_coins
    v.unlock_card_skin = p_skin
    return v

## Mondo 1: La Taverna dei Quattro Assi (9 sfidanti + il Signore della Taverna).
static func get_world_1_roster() -> Array[CampaignVillain]:
    var roster: Array[CampaignVillain] = []
    roster.append(_make(
        "w1_v1", "Grog il Mescitore", "Il Barista Distratto",
        "Versa più birra di quanta ne beva, e gioca a carte con la stessa disattenzione.",
        0.10, false, false, false, 50, 0, ""
    ))
    roster.append(_make(
        "w1_v2", "Marchetta delle Quattro Dita", "La Baratta",
        "Bara quanto le permette la fortuna, non le regole del tavolo.",
        0.20, false, false, false, 60, 0, ""
    ))
    roster.append(_make(
        "w1_v3", "Fra Bonaccio il Questuante", "Il Monaco Paziente",
        "Gioca con una calma disarmante: sembra sempre un passo avanti a tutti.",
        0.30, false, false, false, 70, 0, ""
    ))
    roster.append(_make(
        "w1_v4", "Occhio di Falco Lenard", "Il Cacciatore di Scarti",
        "Studia ogni carta scartata come una preda da non lasciarsi sfuggire.",
        0.40, false, false, false, 85, 0, ""
    ))
    roster.append(_make(
        "w1_v5", "Ember la Fabbra", "L'Incudine Silenziosa",
        "Forgia le sue calate senza fretta — e quasi senza errori.",
        0.48, false, false, false, 100, 0, ""
    ))
    roster.append(_make(
        "w1_v6", "Ser Cadoc lo Scudiero", "L'Apprendista dello Scudo",
        "Ha imparato un solo trucco dal suo maestro: congelare il monte scarti nel momento peggiore.",
        0.56, true, false, false, 115, 5, ""
    ))
    roster.append(_make(
        "w1_v7", "La Contessa dei Sette Veli", "La Collezionista",
        "Non scarta mai una carta che sospetta tu possa volere.",
        0.65, false, false, false, 130, 8, ""
    ))
    roster.append(_make(
        "w1_v8", "Grimjaw l'Orco Baro", "Il Rissoso",
        "Gioca sporco quanto le regole della Taverna gli permettono — e anche un po' di più.",
        0.75, true, false, false, 150, 10, ""
    ))
    roster.append(_make(
        "w1_v9", "Maestro Yew delle Radici Antiche", "L'Ultimo Ostacolo",
        "Il più anziano avventore della Taverna: ha visto ogni trucco, e li ricorda tutti.",
        0.86, true, false, false, 175, 12, ""
    ))
    roster.append(_make(
        "w1_boss", "Ostwald, Signore della Taverna", "Il Campione dei Quattro Assi",
        "Non ha mai perso una mano nella sua taverna. Non comincerà certo con te.",
        0.97, true, true, true, 300, 40, "card_back_taverna_quattro_assi"
    ))
    return roster
