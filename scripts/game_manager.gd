class_name BurracoGameManager
extends Node

const BurracoCardData = preload("res://scripts/card_data.gd")
const BurracoDeck = preload("res://scripts/deck.gd")
const BurracoRules = preload("res://scripts/rules.gd")
const BurracoAI = preload("res://scripts/ai_player.gd")
const CardView = preload("res://scripts/card_view.gd")
const CampaignVillain = preload("res://scripts/campaign_data.gd")


enum Phase { DRAW, PLAY, DISCARD }
enum GameMode { CLASSIC, WILD }

@export var current_mode: GameMode = GameMode.WILD
@export var is_player_turn: bool = true
@export var current_phase: Phase = Phase.DRAW
@export var player_has_pozzetto: bool = false
@export var opponent_has_pozzetto: bool = false
@export var match_over: bool = false
var discard_frozen_turns: int = 0
var is_animating: bool = false

# Modalità Storia: il villain attivo (null = partita rapida normale)
var active_villain: CampaignVillain = null
# Modalità Storia: id dei villain già battuti in questa sessione di gioco
# (solo in memoria: non c'è ancora un salvataggio persistente tra sessioni)
var defeated_villain_ids: Dictionary = {}

var deck: BurracoDeck = BurracoDeck.new()
var player_hand: Array[BurracoCardData] = []
var opponent_hand: Array[BurracoCardData] = []
var player_melds: Array[BurracoRules.BurracoMeld] = []
var opponent_melds: Array[BurracoRules.BurracoMeld] = []
var selected_cards: Array[BurracoCardData] = []

# Riferimenti UI (iniettati o cercati)
@onready var hand_container: HBoxContainer = $"../UI/TableLayer/HandContainer"
@onready var melds_container: HBoxContainer = $"../UI/TableLayer/PlayerMelds"
@onready var opp_melds_container: HBoxContainer = $"../UI/TableLayer/OpponentMelds"
@onready var status_label: Label = $"../UI/TableLayer/StatusLabel"
@onready var opp_count_label: Label = $"../UI/TableLayer/OppCountLabel"
@onready var discard_top_view: Control = get_node_or_null("../UI/TableLayer/CenterArea/DiscardTop")
@onready var stock_btn: BaseButton = $"../UI/TableLayer/CenterArea/StockButton"
@onready var stock_label: Label = get_node_or_null("../UI/TableLayer/CenterArea/StockLabel")
@onready var pozzetto_p_card: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/CardBack")
@onready var pozzetto_p_shadow: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/Shadow")
@onready var pozzetto_p_empty: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/EmptySlot")
@onready var pozzetto_p_badge: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/Badge")
@onready var pozzetto_p_badge_lbl: Label = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/Badge/BadgeLabel")
@onready var pozzetto_p_label: Label = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayerLabel")
@onready var pozzetto_p_btn: BaseButton = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoPlayer/PozzettoPlayerBtn")

@onready var pozzetto_o_card: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/CardBack")
@onready var pozzetto_o_shadow: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/Shadow")
@onready var pozzetto_o_empty: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/EmptySlot")
@onready var pozzetto_o_badge: Control = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/Badge")
@onready var pozzetto_o_badge_lbl: Label = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/Badge/BadgeLabel")
@onready var pozzetto_o_label: Label = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponentLabel")
@onready var pozzetto_o_btn: BaseButton = get_node_or_null("../UI/TableLayer/CenterArea/PozzettoOpponent/PozzettoOppBtn")
@onready var discard_btn_action: BaseButton = get_node_or_null("../UI/TableLayer/CenterArea/TakeDiscardButton")
@onready var discard_label_btn: BaseButton = $"../UI/TableLayer/CenterArea/TakeDiscardLabelBtn"
@onready var discard_scroll: ScrollContainer = get_node_or_null("../UI/TableLayer/CenterArea/DiscardScroll")
@onready var discard_cards_box: HBoxContainer = get_node_or_null("../UI/TableLayer/CenterArea/DiscardScroll/DiscardCardsBox")
@onready var meld_btn: Button = $"../UI/TableLayer/Actions/MeldBtn"
@onready var discard_hand_btn: Button = $"../UI/TableLayer/Actions/DiscardBtn"
@onready var sort_suit_btn: Button = $"../UI/TableLayer/Actions/SortSuitBtn"
@onready var sort_rank_btn: Button = $"../UI/TableLayer/Actions/SortRankBtn"
@onready var modal_end: Panel = $"../UI/ModalEndMatch"
@onready var result_label: Label = $"../UI/ModalEndMatch/ResultLabel"
@onready var score_label: Label = $"../UI/ModalEndMatch/ScoreLabel"
@onready var mode_btn: Button = get_node_or_null("../UI/HeaderBar/ModeToggleBtn")
@onready var opp_status_lbl: Label = get_node_or_null("../UI/TableLayer/OpponentProfileCard/OppInfoVBox/OppStatusLabel")
@onready var turn_ring_opp: Panel = get_node_or_null("../UI/TableLayer/OpponentProfileCard/TurnRingOpp")
@onready var turn_ring_player: Panel = get_node_or_null("../UI/TableLayer/PlayerProfileCard/TurnRingPlayer")
@onready var live_score_p: Label = get_node_or_null("../UI/TableLayer/LiveScoreboard/LiveScoreVBox/LiveScorePlayer")
@onready var live_score_o: Label = get_node_or_null("../UI/TableLayer/LiveScoreboard/LiveScoreVBox/LiveScoreOpp")

var ai: BurracoAI = BurracoAI.new()
var card_view_script = preload("res://scripts/card_view.gd")

func _ready() -> void:
    if stock_btn: stock_btn.pressed.connect(on_player_draw_stock)
    if pozzetto_p_btn:
        pozzetto_p_btn.pressed.connect(func():
            if player_has_pozzetto:
                set_banner("TUO POZZETTO: Già preso!")
            else:
                set_banner("TUO POZZETTO (11 carte): Lo prenderai automaticamente appena esaurirai le carte in mano!")
        )
    if pozzetto_o_btn:
        pozzetto_o_btn.pressed.connect(func():
            if opponent_has_pozzetto:
                set_banner("POZZETTO AVVERSARIO: Già preso dall'avversario!")
            else:
                set_banner("POZZETTO AVVERSARIO (11 carte): L'avversario lo prenderà appena esaurirà la propria mano!")
        )
    if discard_label_btn: discard_label_btn.pressed.connect(on_player_take_discard)
    if meld_btn: meld_btn.pressed.connect(on_player_meld_selected)
    if discard_hand_btn: discard_hand_btn.pressed.connect(on_player_discard_selected)
    if sort_suit_btn: sort_suit_btn.pressed.connect(sort_by_suit)
    if sort_rank_btn: sort_rank_btn.pressed.connect(sort_by_rank)
    if mode_btn:
        mode_btn.pressed.connect(toggle_game_mode)
        _update_mode_btn()
    if modal_end: modal_end.visible = false
    var restart_btn = get_node_or_null("../UI/ModalEndMatch/RestartBtn")
    if restart_btn:
        restart_btn.pressed.connect(func():
            if modal_end: modal_end.visible = false
            start_new_match()
        )
    _wrap_melds_in_scroll(melds_container)
    _wrap_melds_in_scroll(opp_melds_container)
    start_new_match()

## Con molte calate lunghe (specie con Jolly) la fila puo' superare la
## larghezza dello schermo: incastona l'HBoxContainer delle calate in uno
## ScrollContainer orizzontale che ne prende posizione/anchor, cosi' invece
## di uscire dai bordi diventa scorrevole (come gia' avviene per gli scarti).
func _wrap_melds_in_scroll(container: HBoxContainer) -> void:
    if container == null:
        return
    var parent = container.get_parent()
    if parent == null or container.get_meta("_scroll_wrapped", false):
        return
    var idx = container.get_index()

    var scroll = ScrollContainer.new()
    scroll.name = container.name + "Scroll"
    scroll.layout_mode = container.layout_mode
    scroll.anchors_preset = container.anchors_preset
    scroll.anchor_left = container.anchor_left
    scroll.anchor_top = container.anchor_top
    scroll.anchor_right = container.anchor_right
    scroll.anchor_bottom = container.anchor_bottom
    scroll.offset_left = container.offset_left
    scroll.offset_top = container.offset_top
    scroll.offset_right = container.offset_right
    scroll.offset_bottom = container.offset_bottom
    scroll.grow_horizontal = container.grow_horizontal
    scroll.grow_vertical = container.grow_vertical
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

    parent.add_child(scroll)
    parent.move_child(scroll, idx)
    parent.remove_child(container)
    scroll.add_child(container)

    container.layout_mode = 0
    container.set_anchors_preset(Control.PRESET_TOP_LEFT)
    container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    container.set_meta("_scroll_wrapped", true)

func toggle_game_mode() -> void:
    if current_mode == GameMode.CLASSIC:
        current_mode = GameMode.WILD
        set_banner("⚡ MODALITÀ WILD BURRACO ATTIVATA: I tratti speciali delle carte sono attivi!")
    else:
        current_mode = GameMode.CLASSIC
        set_banner("🏆 MODALITÀ CLASSICA ATTIVATA: Regole F.I.BUR ufficiali pure e moltiplicatore fiches!")
    _update_mode_btn()
    refresh_all_ui()

func _update_mode_btn() -> void:
    if mode_btn == null: return
    if current_mode == GameMode.WILD:
        mode_btn.text = "⚡ WILD BURRACO"
        mode_btn.modulate = Color(0.4, 0.95, 1.0)
    else:
        mode_btn.text = "🏆 CLASSICO"
        mode_btn.modulate = Color(1.0, 0.88, 0.3)

func start_new_match() -> void:
    match_over = false
    is_player_turn = true
    current_phase = Phase.DRAW
    player_has_pozzetto = false
    opponent_has_pozzetto = false
    player_melds.clear()
    opponent_melds.clear()
    selected_cards.clear()

    deck.initialize_and_deal(player_hand, opponent_hand)
    refresh_all_ui()

## Avvia una sfida della modalità Storia contro un villain del roster (campaign_data.gd).
## Applica il suo grado di difficoltà e il suo tratto firma all'IA prima di smazzare.
func start_campaign_match(villain: CampaignVillain) -> void:
    active_villain = villain
    ai.difficulty = villain.difficulty
    ai.five_freeze_priority = villain.five_freeze_priority
    current_mode = GameMode.WILD
    start_new_match()

## Avvia "Burraco Veloce" con un'IA a difficoltà standard, azzerando qualsiasi
## stato lasciato da una precedente sfida della Campagna (difficoltà/tratto del
## villain, ricompense e flag di vittoria del villain), altrimenti quello stato
## resterebbe attivo per il resto della sessione anche fuori dalla Storia.
func start_quick_match() -> void:
    active_villain = null
    ai.difficulty = 0.5
    ai.five_freeze_priority = false
    start_new_match()

var discard_inspector_modal: Control = null
var inspector_cards_box: GridContainer = null
var inspector_title: Label = null
var inspector_take_btn: Button = null

func _build_discard_inspector() -> void:
    var ui_root = get_node_or_null("../UI")
    if ui_root == null: return

    discard_inspector_modal = Control.new()
    discard_inspector_modal.name = "DiscardInspectorModal"
    discard_inspector_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    discard_inspector_modal.z_index = 65
    discard_inspector_modal.visible = false
    ui_root.add_child(discard_inspector_modal)

    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.8)
    discard_inspector_modal.add_child(bg)

    var viewport_size = ui_root.get_viewport().get_visible_rect().size
    var p_size = Vector2(min(660.0, viewport_size.x - 40.0), min(920.0, viewport_size.y - 120.0))
    var p = Panel.new()
    p.custom_minimum_size = p_size
    p.size = p_size
    p.position = ((viewport_size - p_size) / 2.0).round()
    var psb = StyleBoxFlat.new()
    psb.bg_color = Color(0.06, 0.11, 0.08, 0.98)
    psb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    psb.set_border_width_all(3)
    psb.set_corner_radius_all(12)
    psb.shadow_size = 14
    psb.shadow_color = Color(0, 0, 0, 0.7)
    p.add_theme_stylebox_override("panel", psb)
    discard_inspector_modal.add_child(p)

    inspector_title = Label.new()
    inspector_title.text = "🎴 MONTE DEGLI SCARTI"
    inspector_title.position = Vector2(24, 16)
    inspector_title.size = Vector2(p_size.x - 130, 26)
    inspector_title.add_theme_font_size_override("font_size", 19)
    inspector_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
    p.add_child(inspector_title)

    var sub = Label.new()
    sub.text = "Esamina tutte le carte nel monte prima di decidere se raccoglierle o pescare dal tallone"
    sub.position = Vector2(24, 44)
    sub.size = Vector2(p_size.x - 48, 32)
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", 12)
    sub.add_theme_color_override("font_color", Color(0.75, 0.85, 0.8, 1.0))
    p.add_child(sub)

    var close_btn = Button.new()
    close_btn.text = "✖"
    close_btn.custom_minimum_size = Vector2(40, 36)
    close_btn.position = Vector2(p_size.x - 24 - 40, 14)
    var csb = StyleBoxFlat.new()
    csb.bg_color = Color(0.2, 0.1, 0.12, 0.9)
    csb.border_color = Color(0.9, 0.4, 0.4, 1.0)
    csb.set_border_width_all(2)
    csb.set_corner_radius_all(6)
    close_btn.add_theme_stylebox_override("normal", csb)
    close_btn.pressed.connect(func(): discard_inspector_modal.visible = false)
    p.add_child(close_btn)

    var actions_h = 96.0
    var scroll = ScrollContainer.new()
    scroll.position = Vector2(20, 84)
    scroll.size = Vector2(p_size.x - 40, p_size.y - 84 - actions_h)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    p.add_child(scroll)

    inspector_cards_box = GridContainer.new()
    inspector_cards_box.columns = 4
    inspector_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inspector_cards_box.add_theme_constant_override("h_separation", 14)
    inspector_cards_box.add_theme_constant_override("v_separation", 16)
    scroll.add_child(inspector_cards_box)

    var b_box = VBoxContainer.new()
    b_box.position = Vector2(20, p_size.y - actions_h + 6)
    b_box.size = Vector2(p_size.x - 40, actions_h - 10)
    b_box.add_theme_constant_override("separation", 8)
    p.add_child(b_box)

    inspector_take_btn = Button.new()
    inspector_take_btn.custom_minimum_size = Vector2(0, 42)
    inspector_take_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inspector_take_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var tsb = StyleBoxFlat.new()
    tsb.bg_color = Color(0.12, 0.35, 0.18, 0.98)
    tsb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    tsb.set_border_width_all(2)
    tsb.set_corner_radius_all(8)
    inspector_take_btn.add_theme_stylebox_override("normal", tsb)
    inspector_take_btn.add_theme_font_size_override("font_size", 15)
    inspector_take_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
    inspector_take_btn.pressed.connect(func():
        on_player_take_discard()
        if discard_inspector_modal: discard_inspector_modal.visible = false
    )
    b_box.add_child(inspector_take_btn)

    var btn_stock_draw = Button.new()
    btn_stock_draw.text = "↩️  PREFERISCO PESCARE DAL TALLONE"
    btn_stock_draw.custom_minimum_size = Vector2(0, 38)
    btn_stock_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn_stock_draw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var ssb = StyleBoxFlat.new()
    ssb.bg_color = Color(0.16, 0.2, 0.26, 0.95)
    ssb.border_color = Color(0.5, 0.7, 0.9, 1.0)
    ssb.set_border_width_all(2)
    ssb.set_corner_radius_all(8)
    btn_stock_draw.add_theme_stylebox_override("normal", ssb)
    btn_stock_draw.add_theme_font_size_override("font_size", 13)
    btn_stock_draw.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
    btn_stock_draw.pressed.connect(func():
        discard_inspector_modal.visible = false
    )
    b_box.add_child(btn_stock_draw)

func open_discard_inspector() -> void:
    if deck.discard_pile.is_empty():
        set_banner("Il monte degli scarti è vuoto.")
        return

    if discard_inspector_modal == null:
        _build_discard_inspector()

    if inspector_cards_box:
        for c in inspector_cards_box.get_children():
            c.queue_free()

        var pile_size = deck.discard_pile.size()
        for idx in range(pile_size):
            var card = deck.discard_pile[idx]
            var card_holder = VBoxContainer.new()
            card_holder.alignment = BoxContainer.ALIGNMENT_CENTER
            card_holder.add_theme_constant_override("separation", 4)
            inspector_cards_box.add_child(card_holder)

            var cv = CardView.new()
            card_holder.add_child(cv)
            cv.setup(card)

            var tag = Label.new()
            tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            tag.add_theme_font_size_override("font_size", 10)
            if idx == pile_size - 1:
                tag.text = "ULTIMO SCARTO"
                tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
            else:
                tag.text = "#%d" % (idx + 1)
                tag.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
            card_holder.add_child(tag)

    if inspector_title:
        inspector_title.text = "🎴 MONTE DEGLI SCARTI (%d CARTE DISPONIBILI)" % deck.discard_pile.size()

    if inspector_take_btn:
        var can_take = is_player_turn and current_phase == Phase.DRAW and not (current_mode == GameMode.WILD and discard_frozen_turns > 0)
        inspector_take_btn.disabled = not can_take
        if can_take:
            inspector_take_btn.text = "📥  RACCOGLI TUTTO IL MONTE (%d CARTE)" % deck.discard_pile.size()
        else:
            inspector_take_btn.text = "🔒  NON PUOI RACCOGLIERE ORA"

    discard_inspector_modal.visible = true

func on_player_draw_stock() -> void:
    if not is_player_turn or current_phase != Phase.DRAW or match_over: return
    var drawn = deck.draw_from_stock()
    if drawn != null:
        player_hand.append(drawn)
        current_phase = Phase.PLAY
        refresh_all_ui()

func on_player_take_discard() -> void:
    if not is_player_turn or current_phase != Phase.DRAW or match_over: return
    if current_mode == GameMode.WILD and discard_frozen_turns > 0:
        set_banner("❄️ MONTE SCARTI CONGELATO! Lo Scudo del Paladino blocca la raccolta questo turno!")
        return

    var taken = deck.take_entire_discard_pile()
    if not taken.is_empty():
        player_hand.append_array(taken)
        current_phase = Phase.PLAY
        var audio = get_node_or_null("/root/AudioSynth")
        if audio and audio.has_method("play_card_slide"):
            audio.play_card_slide()
        refresh_all_ui()
func on_player_meld_selected() -> void:
    if not is_player_turn or current_phase != Phase.PLAY or match_over or is_animating: return
    if selected_cards.is_empty(): return

    # REGOLA F.I.BUR: Dopo aver preso il pozzetto non puoi calare tutte le carte a zero
    if player_has_pozzetto and selected_cards.size() >= player_hand.size():
        var has_b = false
        for m in player_melds:
            if m.cards.size() >= 7:
                has_b = true
                break
        if not has_b:
            set_banner("⚠️ REGOLA F.I.BUR: Non puoi restare senza carte senza aver prima realizzato almeno un BURRACO (7+ carte)!")
            return
        else:
            set_banner("⚠️ REGOLA F.I.BUR: La chiusura deve avvenire con uno scarto! Tieni almeno 1 carta in mano.")
            return

    # 1. Se ci sono calate esistenti, verifica se le carte selezionate possono attaccarsi
    var target_meld: BurracoRules.BurracoMeld = null
    for m in player_melds:
        if BurracoRules.can_attach_cards_to_meld(m, selected_cards):
            target_meld = m
            break

    # 2. Se sono 3 o più carte, verifica se possono formare una nuova calata
    var new_meld_res = {"valid": false}
    if selected_cards.size() >= 3:
        new_meld_res = BurracoRules.validate_new_meld(selected_cards)

    # Se forma una nuova calata ed è valida, e non c'è calata target da estendere
    if new_meld_res.valid and target_meld == null:
        _animate_meld_flight(selected_cards.duplicate(), new_meld_res)
        return

    # Se può attaccarsi a una calata esistente e non forma nuova calata (o sono < 3 carte):
    if target_meld != null and not new_meld_res.valid:
        _animate_meld_attach(selected_cards.duplicate(), target_meld)
        return

    # Se può fare entrambe le cose, diamo priorità a nuova calata
    if new_meld_res.valid:
        _animate_meld_flight(selected_cards.duplicate(), new_meld_res)
        return

    if target_meld != null:
        _animate_meld_attach(selected_cards.duplicate(), target_meld)
        return

    # Altrimenti segnala errore
    if selected_cards.size() < 3:
        set_banner("Le carte selezionate non possono essere attaccate a nessuna calata esistente.")
    else:
        var err = new_meld_res.get("error", "Combinazione non valida.")
        set_banner(err)

func _animate_meld_attach(cards_to_attach: Array[BurracoCardData], target_meld: BurracoRules.BurracoMeld) -> void:
    is_animating = true
    if meld_btn: meld_btn.disabled = true
    if discard_hand_btn: discard_hand_btn.disabled = true

    var flying_data: Array[Dictionary] = []
    for c in cards_to_attach:
        var found_cv: CardView = null
        if hand_container:
            for child in hand_container.get_children():
                if child is CardView and child.card_data == c:
                    found_cv = child
                    break
        if found_cv:
            flying_data.append({
                "card": c,
                "start_pos": found_cv.global_position,
                "start_scale": found_cv.scale,
                "start_rot": found_cv.rotation
            })
            found_cv.visible = false
        else:
            flying_data.append({
                "card": c,
                "start_pos": Vector2(640, 580),
                "start_scale": Vector2.ONE,
                "start_rot": 0.0
            })

    var target_idx = player_melds.find(target_meld)
    if target_idx == -1: target_idx = 0
    var target_base_y = 430.0
    var target_base_x = 360.0
    if melds_container:
        target_base_y = melds_container.global_position.y + 20.0
        target_base_x = melds_container.global_position.x + 30.0 + target_idx * 160.0

    var table_layer = get_node_or_null("../UI/TableLayer")
    var flying_nodes: Array[CardView] = []
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_card_slide"):
        audio.play_card_slide()

    for i in range(flying_data.size()):
        var d = flying_data[i]
        var fcv = CardView.new()
        fcv.top_level = true
        fcv.z_index = 80
        if table_layer:
            table_layer.add_child(fcv)
        else:
            add_child(fcv)
        fcv.setup(d.card, true)
        fcv.global_position = d.start_pos
        fcv.scale = d.start_scale
        fcv.rotation = d.start_rot
        flying_nodes.append(fcv)

    var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    for i in range(flying_nodes.size()):
        var fcv = flying_nodes[i]
        var card_target = Vector2(target_base_x + (target_meld.cards.size() + i) * 22.0, target_base_y)
        var delay = i * 0.04
        tween.tween_property(fcv, "global_position", card_target, 0.36).set_delay(delay)
        tween.tween_property(fcv, "scale", Vector2.ONE, 0.36).set_delay(delay)
        tween.tween_property(fcv, "rotation", 0.0, 0.36).set_delay(delay)

    tween.finished.connect(func():
        for fcv in flying_nodes:
            fcv.queue_free()

        target_meld.cards.append_array(cards_to_attach)
        BurracoRules.sort_meld_cards(target_meld)

        if current_mode == GameMode.WILD:
            for c in cards_to_attach:
                if c.rank == BurracoCardData.Rank.JACK:
                    set_banner("⚔️ CAVALIERE IMPAVIDO! Hai rubato 15 Fiches all'avversario!")
                elif c.rank == BurracoCardData.Rank.QUEEN:
                    if not deck.stock_pile.is_empty():
                        var next_c = deck.stock_pile.back()
                        set_banner("🔮 OCCHIO INCANTATRICE! In cima al tallone c'e: %s %s" % [next_c.get_rank_string(), next_c.get_suit_symbol()])

        for c in cards_to_attach: player_hand.erase(c)
        selected_cards.clear()

        if audio and audio.has_method("play_card_place"):
            audio.play_card_place()

        if target_meld.cards.size() >= 7:
            if audio and audio.has_method("play_burraco_fanfare"):
                audio.play_burraco_fanfare()
            var b_type = target_meld.get_burraco_type()
            var ParticleFx = preload("res://scripts/particle_effects.gd")
            if table_layer:
                ParticleFx.burst_burraco(table_layer, Vector2(target_base_x + 50.0, target_base_y), b_type as int)
            var type_name = "PULITO (+200 pt)!" if b_type == BurracoRules.BurracoType.CLEAN else ("SEMIPULITO (+150 pt)!" if b_type == BurracoRules.BurracoType.SEMI_CLEAN else "SPORCO (+100 pt)!")
            set_banner("🎉 BURRACO %s CONQUISTATO!" % type_name)

        if player_hand.is_empty() and not player_has_pozzetto:
            player_hand = deck.take_player_pozzetto()
            player_has_pozzetto = true
            set_banner("POZZETTO AL VOLO! Continua a calare con la nuova mano!")

        is_animating = false
        refresh_all_ui()
    )

func _animate_meld_flight(cards_to_meld: Array[BurracoCardData], res: Dictionary) -> void:
    is_animating = true
    if meld_btn: meld_btn.disabled = true
    if discard_hand_btn: discard_hand_btn.disabled = true

    var flying_data: Array[Dictionary] = []
    for c in cards_to_meld:
        var found_cv: CardView = null
        if hand_container:
            for child in hand_container.get_children():
                if child is CardView and child.card_data == c:
                    found_cv = child
                    break
        if found_cv:
            flying_data.append({
                "card": c,
                "start_pos": found_cv.global_position,
                "start_scale": found_cv.scale,
                "start_rot": found_cv.rotation
            })
            found_cv.visible = false
        else:
            flying_data.append({
                "card": c,
                "start_pos": Vector2(640, 580),
                "start_scale": Vector2.ONE,
                "start_rot": 0.0
            })

    # Calcolo posizione destinazione nel melds_container
    var target_base_y = 430.0
    var target_base_x = 360.0
    if melds_container:
        target_base_y = melds_container.global_position.y + 20.0
        var existing_count = player_melds.size()
        target_base_x = melds_container.global_position.x + 30.0 + existing_count * 160.0

    var table_layer = get_node_or_null("../UI/TableLayer")
    var flying_nodes: Array[CardView] = []
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_card_slide"):
        audio.play_card_slide()

    for i in range(flying_data.size()):
        var d = flying_data[i]
        var fcv = CardView.new()
        fcv.top_level = true
        fcv.z_index = 80
        if table_layer:
            table_layer.add_child(fcv)
        else:
            add_child(fcv)
        fcv.setup(d.card, true)
        fcv.global_position = d.start_pos
        fcv.scale = d.start_scale
        fcv.rotation = d.start_rot
        flying_nodes.append(fcv)

    var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    for i in range(flying_nodes.size()):
        var fcv = flying_nodes[i]
        var card_target = Vector2(target_base_x + i * 26.0, target_base_y)
        var delay = i * 0.04
        tween.tween_property(fcv, "global_position", card_target, 0.36).set_delay(delay)
        tween.tween_property(fcv, "scale", Vector2.ONE, 0.36).set_delay(delay)
        tween.tween_property(fcv, "rotation", 0.0, 0.36).set_delay(delay)

    tween.finished.connect(func():
        for fcv in flying_nodes:
            fcv.queue_free()

        var meld = BurracoRules.BurracoMeld.new()
        meld.id = "pm_" + str(player_melds.size() + 1)
        meld.type = res.type
        if res.has("suit"): meld.suit = res.suit
        if res.has("rank"): meld.rank = res.rank
        meld.cards = cards_to_meld.duplicate()
        meld.is_player = true
        BurracoRules.sort_meld_cards(meld)
        player_melds.append(meld)

        # Tratti Wild Burraco attivati alla calata
        if current_mode == GameMode.WILD:
            for c in cards_to_meld:
                if c.rank == BurracoCardData.Rank.JACK:
                    set_banner("⚔️ CAVALIERE IMPAVIDO! Hai rubato 15 Fiches all'avversario!")
                elif c.rank == BurracoCardData.Rank.QUEEN:
                    if not deck.stock_pile.is_empty():
                        var next_c = deck.stock_pile.back()
                        set_banner("🔮 OCCHIO INCANTATRICE! In cima al tallone c'e: %s %s" % [next_c.get_rank_string(), next_c.get_suit_symbol()])

        for c in cards_to_meld: player_hand.erase(c)
        selected_cards.clear()

        if audio and audio.has_method("play_card_place"):
            audio.play_card_place()

        # Sigillo e Fanfara se Burraco
        if meld.cards.size() >= 7:
            if audio and audio.has_method("play_burraco_fanfare"):
                audio.play_burraco_fanfare()
            var b_type = meld.get_burraco_type()
            var ParticleFx = preload("res://scripts/particle_effects.gd")
            if table_layer:
                ParticleFx.burst_burraco(table_layer, Vector2(target_base_x + 50.0, target_base_y), b_type as int)
            var type_name = "PULITO (+200 pt)!" if b_type == BurracoRules.BurracoType.CLEAN else ("SEMIPULITO (+150 pt)!" if b_type == BurracoRules.BurracoType.SEMI_CLEAN else "SPORCO (+100 pt)!")
            set_banner("🎉 BURRACO %s CONQUISTATO!" % type_name)

        # Pozzetto al volo
        if player_hand.is_empty() and not player_has_pozzetto:
            player_hand = deck.take_player_pozzetto()
            player_has_pozzetto = true
            set_banner("POZZETTO AL VOLO! Continua a calare con la nuova mano!")

        is_animating = false
        refresh_all_ui()
    )

func on_player_discard_selected() -> void:
    if not is_player_turn or current_phase != Phase.PLAY or match_over: return
    if selected_cards.size() != 1:
        set_banner("Seleziona 1 sola carta da scartare!")
        return

    var card = selected_cards[0]

    # REGOLA UFFICIALE F.I.BUR:
    # Se il giocatore ha già preso il Pozzetto ed è rimasto con 1 sola carta in mano,
    # NON PUÒ scartare l'ultima carta (andando a 0) se non ha completato almeno un BURRACO (7+ carte)!
    if player_has_pozzetto and player_hand.size() == 1:
        var has_burraco = false
        for m in player_melds:
            if m.cards.size() >= 7:
                has_burraco = true
                break
        if not has_burraco:
            set_banner("⚠️ REGOLA F.I.BUR: Non puoi scartare l'ultima carta né chiudere senza aver realizzato almeno un BURRACO (7+ carte)!")
            return

    player_hand.erase(card)
    deck.discard(card)
    selected_cards.clear()

    # Tratto Wild: 5 congela il monte scarti per l'avversario
    if current_mode == GameMode.WILD and card.rank == BurracoCardData.Rank.FIVE:
        discard_frozen_turns = 1
        set_banner("🛡️ SCUDO DEL PALADINO! Il monte scarti e congelato per il prossimo turno avversario!")

    # Pozzetto con scarto o chiusura
    if player_hand.is_empty():
        if not player_has_pozzetto:
            player_hand = deck.take_player_pozzetto()
            player_has_pozzetto = true
            set_banner("Hai preso il Pozzetto con lo scarto! Giocherai al prossimo turno.")
        else:
            var has_b = false
            for m in player_melds: if m.cards.size() >= 7: has_b = true
            if has_b:
                end_match(true)
                return

    is_player_turn = false
    current_phase = Phase.DRAW
    refresh_all_ui()
    _run_ai_turn()

func _run_ai_turn() -> void:
    await get_tree().create_timer(1.2).timeout
    if match_over: return

    # 1. Pesca AI
    var top = deck.peek_top_discard()
    var can_ai_take = (top != null and (current_mode != GameMode.WILD or discard_frozen_turns == 0))
    if can_ai_take and ai.decide_draw_from_discard(top, opponent_hand, opponent_melds):
        opponent_hand.append_array(deck.take_entire_discard_pile())
        set_banner("L'avversario ha raccolto il Monte degli Scarti!")
    else:
        var drawn = deck.draw_from_stock()
        if drawn: opponent_hand.append(drawn)
        set_banner("L'avversario ha pescato dal tallone.")

    refresh_all_ui()
    await get_tree().create_timer(1.2).timeout

    # 2. Calata AI
    var possible = ai.find_possible_melds(opponent_hand)
    for combo in possible:
        var res = BurracoRules.validate_new_meld(combo)
        if res.valid:
            var meld = BurracoRules.BurracoMeld.new()
            meld.id = "om_" + str(opponent_melds.size() + 1)
            meld.type = res.type
            if res.has("suit"): meld.suit = res.suit
            if res.has("rank"): meld.rank = res.rank
            meld.cards = combo.duplicate()
            meld.is_player = false
            opponent_melds.append(meld)
            for c in combo: opponent_hand.erase(c)

    if opponent_hand.is_empty() and not opponent_has_pozzetto:
        opponent_hand = deck.take_opponent_pozzetto()
        opponent_has_pozzetto = true
        set_banner("L'avversario ha preso il Pozzetto al volo!")

    await get_tree().create_timer(1.0).timeout

    # 3. Scarto AI
    var to_discard = ai.choose_discard(opponent_hand)
    if to_discard != null:
        opponent_hand.erase(to_discard)
        deck.discard(to_discard)
        if current_mode == GameMode.WILD and to_discard.rank == BurracoCardData.Rank.FIVE:
            var freeze_turns = 2 if (active_villain != null and active_villain.extended_freeze) else 1
            discard_frozen_turns = freeze_turns
            if freeze_turns > 1:
                set_banner("🛡️ %s ha giocato uno SCUDO DEL PALADINO POTENZIATO: Monte Scarti congelato per 2 turni!" % active_villain.display_name)
            else:
                set_banner("🛡️ L'avversario ha giocato lo SCUDO DEL PALADINO: Monte Scarti congelato!")

    if opponent_hand.is_empty():
        if not opponent_has_pozzetto:
            opponent_hand = deck.take_opponent_pozzetto()
            opponent_has_pozzetto = true
            set_banner("L'avversario ha preso il Pozzetto con lo scarto.")
        else:
            var has_b = false
            for m in opponent_melds: if m.cards.size() >= 7: has_b = true
            if has_b:
                end_match(false)
                return

    is_player_turn = true
    current_phase = Phase.DRAW
    if discard_frozen_turns > 0:
        discard_frozen_turns -= 1
    refresh_all_ui()

func end_match(player_won: bool) -> void:
    match_over = true
    if player_won and active_villain != null:
        defeated_villain_ids[active_villain.id] = true
    var is_wild = (current_mode == GameMode.WILD)

    var p_bd = BurracoRules.calculate_player_breakdown(player_melds, player_hand, player_has_pozzetto, player_won, is_wild)
    var o_bd = BurracoRules.calculate_player_breakdown(opponent_melds, opponent_hand, opponent_has_pozzetto, not player_won, is_wild)

    var p_score = p_bd.total
    var o_score = o_bd.total

    var fiches_awarded = 0
    var coins_awarded = 0
    if player_won:
        if active_villain != null:
            fiches_awarded = active_villain.reward_fiches
            coins_awarded = active_villain.reward_coins
        else:
            fiches_awarded = 250
            coins_awarded = 50
        if current_mode == GameMode.CLASSIC:
            var prestige_bonus = 0.0
            for m in player_melds:
                for c in m.cards:
                    prestige_bonus += c.get_classic_fiches_multiplier()
            fiches_awarded = int(fiches_awarded * (1.0 + prestige_bonus))
            coins_awarded = int(coins_awarded * (1.0 + prestige_bonus))

        var fiches_lbl = get_node_or_null("../UI/HeaderBar/Currencies/ChipsLabel")
        if fiches_lbl:
            var cur = fiches_lbl.text.replace(" FICHES", "").replace(",", "").to_int()
            fiches_lbl.text = "%s FICHES" % String.num(cur + fiches_awarded)
        var coins_lbl = get_node_or_null("../UI/HeaderBar/Currencies/CoinsLabel")
        if coins_lbl:
            var cur = coins_lbl.text.replace(" GETTONI", "").replace(",", "").to_int()
            coins_lbl.text = "%d GETTONI" % (cur + coins_awarded)

    var audio = get_node_or_null("/root/AudioSynth")
    if audio:
        if player_won and audio.has_method("play_win_fanfare"):
            audio.play_win_fanfare()
        elif not player_won and audio.has_method("play_defeat"):
            audio.play_defeat()

    if modal_end:
        modal_end.visible = true
        if result_label:
            result_label.text = "🏆 VITTORIA!" if player_won else "SCONFITTA"
            result_label.modulate = Color(1.0, 0.85, 0.2) if player_won else Color(0.9, 0.25, 0.25)
        if score_label:
            var text = ""
            text += "TABELLINO UFFICIALE F.I.BUR\n\n"
            text += "%-22s %8s   %8s\n" % ["CATEGORIA", "TU", "AVV."]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Punti Carte Calate:", p_bd.cards_points, o_bd.cards_points]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Burrachi Puliti (200):", p_bd.clean_count * 200, o_bd.clean_count * 200]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Burrachi Semipul. (150):", p_bd.semi_count * 150, o_bd.semi_count * 150]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Burrachi Sporchi (100):", p_bd.dirty_count * 100, o_bd.dirty_count * 100]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Bonus Chiusura:", p_bd.closure_points, o_bd.closure_points]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Pozzetto Preso/Mancato:", p_bd.pozzetto_penalty, o_bd.pozzetto_penalty]
            text += "%-22s %+7d pt   %+7d pt\n" % ["Penalita Carte in Mano:", p_bd.hand_penalty, o_bd.hand_penalty]
            text += "--------------------------------------------------\n"
            text += "%-22s %+7d pt   %+7d pt\n" % ["TOTALE PARTITA:", p_score, o_score]
            if player_won:
                text += "\n🎁 PREMI VITTORIA: +%d Fiches | +%d Gettoni!" % [fiches_awarded, coins_awarded]
                if active_villain != null and active_villain.unlock_card_skin != "":
                    text += "\n✨ FINITURA CARTA SBLOCCATA: %s!" % active_villain.unlock_card_skin
            score_label.text = text

func refresh_all_ui() -> void:
    # Status
    if status_label:
        if is_player_turn:
            status_label.text = "TUO TURNO: Pesca dal tallone o raccogli gli scarti" if current_phase == Phase.DRAW else "TUO TURNO: Seleziona carte per Calare o Scartare"
            status_label.modulate = Color(1.0, 0.88, 0.35)
        else:
            status_label.text = "TURNO AVVERSARIO..."
            status_label.modulate = Color(0.7, 0.7, 0.7)

    if opp_count_label:
        opp_count_label.text = "Mano Avversario: %d carte" % opponent_hand.size()

    # Turn Rings Pulsanti (Store Style)
    if turn_ring_player:
        if is_player_turn:
            turn_ring_player.modulate = Color(0.3, 1.0, 0.4, 1.0)
        else:
            turn_ring_player.modulate = Color(0.4, 0.4, 0.4, 0.4)

    if turn_ring_opp:
        if not is_player_turn:
            turn_ring_opp.modulate = Color(1.0, 0.85, 0.25, 1.0)
        else:
            turn_ring_opp.modulate = Color(0.4, 0.4, 0.4, 0.4)

    # Status Avversario sotto il nome
    if opp_status_lbl:
        var poz_txt = "✓ Pozzetto Preso" if opponent_has_pozzetto else "🏺 Pozzetto in gioco"
        opp_status_lbl.text = "🂠 %d carte  •  %s" % [opponent_hand.size(), poz_txt]

    # Calcolo Tabellino Punti Live sul Tavolo
    var p_pts = 0
    var p_clean = 0
    var p_dirty = 0
    for m in player_melds:
        for c in m.cards: p_pts += c.get_point_value()
        var bt = m.get_burraco_type()
        if bt == BurracoRules.BurracoType.CLEAN: p_clean += 1
        elif bt in [BurracoRules.BurracoType.SEMI_CLEAN, BurracoRules.BurracoType.DIRTY]: p_dirty += 1
    var p_live_total = p_pts + (p_clean * 200) + (p_dirty * 100)

    var o_pts = 0
    var o_clean = 0
    var o_dirty = 0
    for m in opponent_melds:
        for c in m.cards: o_pts += c.get_point_value()
        var bt = m.get_burraco_type()
        if bt == BurracoRules.BurracoType.CLEAN: o_clean += 1
        elif bt in [BurracoRules.BurracoType.SEMI_CLEAN, BurracoRules.BurracoType.DIRTY]: o_dirty += 1
    var o_live_total = o_pts + (o_clean * 200) + (o_dirty * 100)

    if live_score_p:
        live_score_p.text = "TU: %d pt | %d 🥇  %d 🥈" % [p_live_total, p_clean, p_dirty]
    if live_score_o:
        live_score_o.text = "AVV: %d pt | %d 🥇  %d 🥈" % [o_live_total, o_clean, o_dirty]

    # Bottoni & Tallone
    if stock_btn: stock_btn.disabled = not (is_player_turn and current_phase == Phase.DRAW)
    if stock_label:
        stock_label.text = "TALLONE\n(%d)" % deck.stock_pile.size()

    # Pozzetto Giocatore: piccolo chip "P", acceso se ancora da prendere,
    # spento (scuro) se gia' preso - come nel burraco online.
    var p_count = deck.pozzetto_player.size()
    if pozzetto_p_card: pozzetto_p_card.visible = false
    if pozzetto_p_shadow: pozzetto_p_shadow.visible = false
    if pozzetto_p_empty: pozzetto_p_empty.visible = false
    if pozzetto_p_badge: pozzetto_p_badge.visible = true
    var p_taken = player_has_pozzetto or p_count == 0
    if pozzetto_p_badge: pozzetto_p_badge.modulate = Color(0.4, 0.4, 0.45) if p_taken else Color(1, 1, 1)
    if pozzetto_p_badge_lbl: pozzetto_p_badge_lbl.modulate = Color(0.6, 0.6, 0.65) if p_taken else Color(1.0, 0.9, 0.35)

    # Pozzetto Avversario: stesso chip "P".
    var o_count = deck.pozzetto_opponent.size()
    if pozzetto_o_card: pozzetto_o_card.visible = false
    if pozzetto_o_shadow: pozzetto_o_shadow.visible = false
    if pozzetto_o_empty: pozzetto_o_empty.visible = false
    if pozzetto_o_badge: pozzetto_o_badge.visible = true
    var o_taken = opponent_has_pozzetto or o_count == 0
    if pozzetto_o_badge: pozzetto_o_badge.modulate = Color(0.4, 0.4, 0.45) if o_taken else Color(1, 1, 1)
    if pozzetto_o_badge_lbl: pozzetto_o_badge_lbl.modulate = Color(0.6, 0.6, 0.65) if o_taken else Color(1.0, 0.9, 0.35)
    var has_discards = deck.discard_pile.size() > 0
    var can_take_discard = is_player_turn and current_phase == Phase.DRAW and has_discards and not (current_mode == GameMode.WILD and discard_frozen_turns > 0)
    if discard_label_btn:
        discard_label_btn.disabled = not can_take_discard
        if has_discards:
            discard_label_btn.text = "📥 RACCOGLI MONTE (%d)" % deck.discard_pile.size()
        else:
            discard_label_btn.text = "MONTE VUOTO"
    _update_action_buttons()

    # Aggiorna striscia Monte Scarti a scorrimento tattile (visibile direttamente sul tavolo!)
    if discard_cards_box:
        for c in discard_cards_box.get_children():
            c.queue_free()
        var pile_size = deck.discard_pile.size()
        for idx in range(pile_size):
            var card = deck.discard_pile[idx]
            var cv = CardView.new()
            discard_cards_box.add_child(cv)
            cv.setup(card)
            # Tocco diretto sul monte scarti per raccoglierlo durante la fase di pesca
            cv.card_clicked.connect(func(_clicked_view):
                if is_player_turn and current_phase == Phase.DRAW:
                    on_player_take_discard()
            )
            # Tocca e tieni premuto sulla striscia: apri il monte intero, carta per carta
            cv.use_generic_long_press_preview = false
            cv.card_long_pressed.connect(func(_clicked_view):
                open_discard_inspector()
            )
        # Scorrimento automatico verso l'ultimo scarto
        if discard_scroll and pile_size > 0:
            get_tree().create_timer(0.05).timeout.connect(func():
                if discard_scroll:
                    discard_scroll.scroll_horizontal = 99999
            )

    # Ricrea carte in mano (Balatro style)
    _rebuild_hand_views()
    _rebuild_melds_views()

func _rebuild_hand_views() -> void:
    if hand_container == null: return
    for child in hand_container.get_children():
        child.queue_free()

    var count = player_hand.size()
    var card_w = CardView.CARD_WIDTH
    var avail_w = hand_container.size.x
    if avail_w <= 0.0:
        avail_w = 700.0
    var sep = -20
    if count > 1:
        var needed_sep = (avail_w - count * card_w) / float(count - 1)
        sep = int(min(-20.0, floor(needed_sep)))
        sep = int(max(sep, -card_w * 0.78))
    hand_container.add_theme_constant_override("separation", sep)

    for card in player_hand:
        var cv = CardView.new()
        hand_container.add_child(cv)
        cv.setup(card)
        cv.set_selected(selected_cards.has(card))
        cv.card_clicked.connect(func(c_view):
            toggle_selection(c_view.card_data)
        )
        cv.card_hovered.connect(func(c_view, is_hov):
            _on_card_hovered(c_view, is_hov)
        )

func _rebuild_melds_views() -> void:
    if melds_container:
        for c in melds_container.get_children(): c.queue_free()
        for m in player_melds:
            var col = VBoxContainer.new()
            col.alignment = BoxContainer.ALIGNMENT_CENTER
            col.add_theme_constant_override("separation", 3)
            melds_container.add_child(col)

            var seal = _create_burraco_seal(m)
            if seal:
                col.add_child(seal)

            var cards_box = HBoxContainer.new()
            cards_box.add_theme_constant_override("separation", int(CardView.COMPACT_OVERLAP))
            col.add_child(cards_box)

            for c in m.cards:
                var cv = CardView.new()
                cards_box.add_child(cv)
                cv.setup(c, true)
                cv.card_hovered.connect(func(c_view, is_hov):
                    _on_card_hovered(c_view, is_hov)
                )

    if opp_melds_container:
        for c in opp_melds_container.get_children(): c.queue_free()
        for m in opponent_melds:
            var col = VBoxContainer.new()
            col.alignment = BoxContainer.ALIGNMENT_CENTER
            col.add_theme_constant_override("separation", 3)
            opp_melds_container.add_child(col)

            var seal = _create_burraco_seal(m)
            if seal:
                col.add_child(seal)

            var cards_box = HBoxContainer.new()
            cards_box.add_theme_constant_override("separation", int(CardView.COMPACT_OVERLAP))
            col.add_child(cards_box)

            for c in m.cards:
                var cv = CardView.new()
                cards_box.add_child(cv)
                cv.setup(c, true)
                cv.card_hovered.connect(func(c_view, is_hov):
                    _on_card_hovered(c_view, is_hov)
                )

func _create_burraco_seal(m: BurracoRules.BurracoMeld) -> Control:
    var b_type = m.get_burraco_type()
    if b_type == BurracoRules.BurracoType.NONE:
        return null

    # Il sigillo non deve mai essere piu' largo della fila di carte sotto di
    # esso (stessa formula usata per il layout con card compatta e overlap),
    # altrimenti la colonna della calata si allarga ed esce dallo schermo
    # quando il testo del sigillo e' lungo (es. calate con Jolly).
    var card_row_width = m.cards.size() * (CardView.COMPACT_WIDTH + CardView.COMPACT_OVERLAP) - CardView.COMPACT_OVERLAP

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(card_row_width, 0)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var sb = StyleBoxFlat.new()
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_left = 6
    sb.corner_radius_bottom_right = 6
    sb.border_width_left = 2
    sb.border_width_top = 2
    sb.border_width_right = 2
    sb.border_width_bottom = 2
    sb.content_margin_left = 8
    sb.content_margin_right = 8
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2

    var lbl = Label.new()
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.custom_minimum_size = Vector2(max(card_row_width - 16.0, 40.0), 0)
    lbl.add_theme_font_size_override("font_size", 9)

    match b_type:
        BurracoRules.BurracoType.CLEAN:
            # Dorato Luminoso (+200 pt)
            sb.bg_color = Color(0.14, 0.10, 0.02, 0.95)
            sb.border_color = Color(1.0, 0.84, 0.25, 1.0)
            lbl.text = "🌟 BURRACO PULITO (+200)"
            lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
        BurracoRules.BurracoType.SEMI_CLEAN:
            # Fiammeggiante (+150 pt)
            sb.bg_color = Color(0.18, 0.05, 0.02, 0.95)
            sb.border_color = Color(1.0, 0.42, 0.12, 1.0)
            lbl.text = "🔥 BURRACO SEMIPULITO (+150)"
            lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
        BurracoRules.BurracoType.DIRTY:
            # Argentato / Zaffiro (+100 pt)
            sb.bg_color = Color(0.04, 0.08, 0.15, 0.95)
            sb.border_color = Color(0.68, 0.85, 1.0, 1.0)
            lbl.text = "🛡️ BURRACO SPORCO (+100)"
            lbl.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))

    panel.add_theme_stylebox_override("panel", sb)
    panel.add_child(lbl)
    var tw = panel.create_tween().set_loops()
    tw.tween_property(panel, "modulate:a", 0.82, 0.7).set_trans(Tween.TRANS_SINE)
    tw.tween_property(panel, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
    return panel

func _on_card_hovered(c_view: CardView, is_hov: bool) -> void:
    if not is_hov:
        if status_label:
            if is_player_turn:
                status_label.text = "TUO TURNO: Pesca dal tallone o raccogli gli scarti" if current_phase == Phase.DRAW else "TUO TURNO: Seleziona carte per Calare o Scartare"
                status_label.modulate = Color(1.0, 0.88, 0.35)
            else:
                status_label.text = "TURNO AVVERSARIO..."
                status_label.modulate = Color(0.7, 0.7, 0.7)
        return

    if c_view == null or c_view.card_data == null: return
    var cd = c_view.card_data
    if current_mode == GameMode.WILD:
        var trait_title = cd.get_wild_trait_title()
        var trait_desc = cd.get_wild_trait_desc()
        if trait_title != "":
            set_banner("⚡ [%s] %s: %s" % [cd.creature_name, trait_title, trait_desc])
            if status_label: status_label.modulate = Color(0.4, 0.95, 1.0)
        else:
            set_banner("⚡ [%s] Valore FIBUR: %d pt" % [cd.creature_name, cd.get_point_value()])
            if status_label: status_label.modulate = Color(0.9, 0.9, 0.9)
    else:
        var mult = cd.get_classic_fiches_multiplier()
        if mult > 0.0:
            set_banner("🏆 [%s] Rarita %s: +%d%% Fiches e XP Vittoria (Regole F.I.BUR)" % [cd.creature_name, cd.creature_rarity, int(mult * 100)])
            if status_label: status_label.modulate = Color(1.0, 0.85, 0.3)
        else:
            set_banner("🏆 [%s] Carta Ufficiale F.I.BUR: %d pt" % [cd.creature_name, cd.get_point_value()])
            if status_label: status_label.modulate = Color(0.9, 0.9, 0.9)

func _update_action_buttons() -> void:
    if meld_btn:
        var can_meld = false
        var is_attach = false
        if is_player_turn and current_phase == Phase.PLAY and not selected_cards.is_empty() and not is_animating:
            if selected_cards.size() >= 3 and BurracoRules.validate_new_meld(selected_cards).valid:
                can_meld = true
            else:
                for m in player_melds:
                    if BurracoRules.can_attach_cards_to_meld(m, selected_cards):
                        can_meld = true
                        is_attach = true
                        break
        meld_btn.disabled = not can_meld
        meld_btn.text = "ATTACCA CARTE" if is_attach else "CALA COMBINAZIONE"

    if discard_hand_btn:
        discard_hand_btn.disabled = not (is_player_turn and current_phase == Phase.PLAY and selected_cards.size() == 1 and not is_animating)

func toggle_selection(card: BurracoCardData) -> void:
    if selected_cards.has(card):
        selected_cards.erase(card)
    else:
        selected_cards.append(card)

    for cv in hand_container.get_children():
        if cv is CardView and cv.card_data:
            cv.set_selected(selected_cards.has(cv.card_data))

    _update_action_buttons()

func sort_by_suit() -> void:
    player_hand.sort_custom(func(a, b):
        if a.suit != b.suit: return a.suit < b.suit
        return (a.rank as int) < (b.rank as int)
    )
    refresh_all_ui()

func sort_by_rank() -> void:
    player_hand.sort_custom(func(a, b):
        if a.rank != b.rank: return (a.rank as int) < (b.rank as int)
        return a.suit < b.suit
    )
    refresh_all_ui()

func set_banner(msg: String) -> void:
    if status_label:
        status_label.text = msg

func on_player_sent_chat(text: String) -> void:
    var ui = get_node_or_null("../UI")
    if ui == null: return
    get_tree().create_timer(1.2).timeout.connect(func():
        if not is_instance_valid(ui): return
        var reply = ""
        if "Buona partita" in text or "Ciao" in text:
            reply = "Anche a te! Che vinca il migliore! ⚔️"
        elif "Bella giocata" in text:
            reply = "Grazie mille! Gioco d'astuzia! 😉"
        elif "Che fortuna" in text:
            reply = "La fortuna aiuta gli audaci! 🍀"
        elif "Mannaggia" in text:
            reply = "Non disperare, tutto può ancora cambiare! 🛡️"
        elif "Pozzetto" in text:
            reply = "Grande giocata! Ora tocca a me rimontare! 🏃"
        elif "Burraco" in text:
            reply = "Splendido Burraco! Ma non mi arrendo! 🔥"
        else:
            reply = "Buona giocata! 🂠"
        if ui.has_method("show_opp_speech"):
            ui.show_opp_speech(reply)
    )
