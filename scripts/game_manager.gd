class_name BurracoGameManager
extends Node

const BurracoCardData = preload("res://scripts/card_data.gd")
const BurracoDeck = preload("res://scripts/deck.gd")
const BurracoRules = preload("res://scripts/rules.gd")
const BurracoAI = preload("res://scripts/ai_player.gd")
const CardView = preload("res://scripts/card_view.gd")


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
@onready var discard_top_view: Control = $"../UI/TableLayer/CenterArea/DiscardTop"
@onready var stock_btn: BaseButton = $"../UI/TableLayer/CenterArea/StockButton"
@onready var discard_btn_action: BaseButton = $"../UI/TableLayer/CenterArea/TakeDiscardButton"
@onready var discard_label_btn: BaseButton = $"../UI/TableLayer/CenterArea/TakeDiscardLabelBtn"
@onready var meld_btn: Button = $"../UI/TableLayer/Actions/MeldBtn"
@onready var discard_hand_btn: Button = $"../UI/TableLayer/Actions/DiscardBtn"
@onready var sort_suit_btn: Button = $"../UI/TableLayer/Actions/SortSuitBtn"
@onready var sort_rank_btn: Button = $"../UI/TableLayer/Actions/SortRankBtn"
@onready var modal_end: Panel = $"../UI/ModalEndMatch"
@onready var result_label: Label = $"../UI/ModalEndMatch/ResultLabel"
@onready var score_label: Label = $"../UI/ModalEndMatch/ScoreLabel"
@onready var mode_btn: Button = $"../UI/HeaderBar/ModeToggleBtn"

var ai: BurracoAI = BurracoAI.new()
var card_view_script = preload("res://scripts/card_view.gd")

func _ready() -> void:
    if stock_btn: stock_btn.pressed.connect(on_player_draw_stock)
    if discard_btn_action: discard_btn_action.pressed.connect(on_player_take_discard)
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
    start_new_match()

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
            discard_frozen_turns = 1
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
    var is_wild = (current_mode == GameMode.WILD)

    var p_bd = BurracoRules.calculate_player_breakdown(player_melds, player_hand, player_has_pozzetto, player_won, is_wild)
    var o_bd = BurracoRules.calculate_player_breakdown(opponent_melds, opponent_hand, opponent_has_pozzetto, not player_won, is_wild)

    var p_score = p_bd.total
    var o_score = o_bd.total

    var fiches_awarded = 0
    var coins_awarded = 0
    if player_won:
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

    # Bottoni
    if stock_btn: stock_btn.disabled = not (is_player_turn and current_phase == Phase.DRAW)
    var can_take = is_player_turn and current_phase == Phase.DRAW and deck.discard_pile.size() > 0
    if discard_btn_action: discard_btn_action.disabled = not can_take
    if discard_label_btn: discard_label_btn.disabled = not can_take
    _update_action_buttons()

    # Aggiorna top scarti
    if discard_top_view and discard_top_view.has_method("setup"):
        var top = deck.peek_top_discard()
        if top:
            discard_top_view.visible = true
            discard_top_view.setup(top)
        else:
            discard_top_view.visible = false

    # Ricrea carte in mano (Balatro style)
    _rebuild_hand_views()
    _rebuild_melds_views()

func _rebuild_hand_views() -> void:
    if hand_container == null: return
    for child in hand_container.get_children():
        child.queue_free()

    var count = player_hand.size()
    var sep = -36
    if count > 12:
        sep = clamp(int(-36 - (count - 12) * 2.8), -62, -20)
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
            cards_box.add_theme_constant_override("separation", -42)
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
            cards_box.add_theme_constant_override("separation", -42)
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

    var panel = PanelContainer.new()
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
    lbl.add_theme_font_size_override("font_size", 11)

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
