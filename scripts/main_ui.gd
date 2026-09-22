class_name MainUI
extends CanvasLayer

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CampaignVillain = preload("res://scripts/campaign_data.gd")

enum UIState { MAIN_MENU, IN_GAME }
var current_state: UIState = UIState.MAIN_MENU

@onready var bg_texture_rect: TextureRect = $Background
@onready var header_bar: Panel = $HeaderBar
@onready var table_layer: Control = $TableLayer
@onready var blind_box_layer: Control = $BlindBoxLayer
@onready var club_layer: Control = $ClubLayer

@onready var tab_home_btn: Button = get_node_or_null("HeaderBar/Nav/TabHome")
@onready var tab_table_btn: Button = $HeaderBar/Nav/TabTable
@onready var tab_box_btn: Button = $HeaderBar/Nav/TabBlindBox
@onready var tab_club_btn: Button = $HeaderBar/Nav/TabClub
@onready var sound_btn: Button = get_node_or_null("HeaderBar/Nav/SoundToggleBtn")
@onready var stock_btn: BaseButton = $TableLayer/CenterArea/StockButton

# Home Screen Nodes
var main_menu_layer: Control
var menu_logo: TextureRect
var quick_play_btn: Button
var menu_anim_time: float = 0.0

# Modals
var rules_modal: Control
var story_modal: Control
var story_roster_list: VBoxContainer
var online_modal: Control

func _ready() -> void:
    if bg_texture_rect:
        bg_texture_rect.texture = AssetLoader.get_tex("res://assets/table_felt_luxury.png")

    var back_tex = AssetLoader.get_tex("res://assets/card_back_taverna.png")
    if back_tex == null:
        back_tex = AssetLoader.get_tex("res://assets/card_back_luxury.png")
    if stock_btn is TextureButton:
        stock_btn.texture_normal = back_tex

    var p_card = get_node_or_null("TableLayer/CenterArea/PozzettoPlayer/CardBack")
    if p_card and p_card is TextureRect:
        p_card.texture = back_tex

    var o_card = get_node_or_null("TableLayer/CenterArea/PozzettoOpponent/CardBack")
    if o_card and o_card is TextureRect:
        o_card.texture = back_tex

    # Avatars Setup (Top Store Style) — cornice in legno intagliato + ritratto grande
    var profile_cards: Array = [
        {
            "card": get_node_or_null("TableLayer/OpponentProfileCard"),
            "avatar": get_node_or_null("TableLayer/OpponentProfileCard/AvatarOpp"),
            "ring": get_node_or_null("TableLayer/OpponentProfileCard/TurnRingOpp"),
            "info": get_node_or_null("TableLayer/OpponentProfileCard/OppInfoVBox"),
            "avatar_path": "res://assets/avatar_opponent.png",
            "frame_size": 96.0,
        },
        {
            "card": get_node_or_null("TableLayer/PlayerProfileCard"),
            "avatar": get_node_or_null("TableLayer/PlayerProfileCard/AvatarPlayer"),
            "ring": get_node_or_null("TableLayer/PlayerProfileCard/TurnRingPlayer"),
            "info": get_node_or_null("TableLayer/PlayerProfileCard/PlayerNameLabel"),
            "avatar_path": "res://assets/avatar_player.png",
            "frame_size": 64.0,
        },
    ]
    for entry in profile_cards:
        _apply_taverna_profile_style(entry.card, entry.avatar, entry.ring, entry.info, entry.avatar_path, entry.frame_size)

# Frazione della finestra interna di avatar_frame_wood.jpg (stimata a occhio sull'immagine
# generata): la cornice intagliata non ha un buco trasparente, quindi il ritratto va
# disegnato SOPRA riempiendo esattamente quella finestra, mentre il legno resta visibile
# intorno come bordo.
const AVATAR_WINDOW_LEFT_FRAC: float = 0.19
const AVATAR_WINDOW_TOP_FRAC: float = 0.21
const AVATAR_WINDOW_WIDTH_FRAC: float = 0.63
const AVATAR_WINDOW_HEIGHT_FRAC: float = 0.59

func _apply_taverna_profile_style(card: Control, avatar: TextureRect, turn_ring: Control, info_control: Control, avatar_path: String, frame_size: float) -> void:
    if card == null or avatar == null:
        return

    var frame_tex = AssetLoader.get_tex("res://assets/avatar_frame_wood.jpg")
    if frame_tex == null:
        avatar.texture = AssetLoader.get_tex(avatar_path)
        return

    # Ordine di disegno via z_index (mai move_child: riordinare i figli qui
    # innesca una ri-registrazione dei segnali dei pulsanti dell'header —
    # osservato empiricamente su Godot 4.3, evitato del tutto con z_index).
    var frame_rect = TextureRect.new()
    frame_rect.texture = frame_tex
    frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    frame_rect.position = Vector2.ZERO
    frame_rect.size = Vector2(frame_size, frame_size)
    frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame_rect.z_index = -3
    card.add_child(frame_rect)

    var win_pos = Vector2(frame_size * AVATAR_WINDOW_LEFT_FRAC, frame_size * AVATAR_WINDOW_TOP_FRAC)
    var win_size = Vector2(frame_size * AVATAR_WINDOW_WIDTH_FRAC, frame_size * AVATAR_WINDOW_HEIGHT_FRAC)

    avatar.position = win_pos
    avatar.size = win_size
    avatar.texture = AssetLoader.get_tex(avatar_path)
    avatar.z_index = -2

    if turn_ring:
        turn_ring.position = Vector2.ZERO
        turn_ring.size = Vector2(frame_size, frame_size)
        turn_ring.z_index = -1

    if info_control:
        info_control.position.x = frame_size + 14.0

        var plate_tex = AssetLoader.get_tex("res://assets/nameplate_wood_iso.png")
        if plate_tex != null:
            var plate = TextureRect.new()
            plate.texture = plate_tex
            plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
            plate.position = info_control.position + Vector2(-10.0, -6.0)
            plate.size = info_control.size + Vector2(20.0, 12.0)
            plate.modulate = Color(1.0, 1.0, 1.0, 0.55)
            plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
            plate.z_index = -1
            card.add_child(plate)

    # Quick Chat System
    var chat_btn = get_node_or_null("TableLayer/QuickChatBtn")
    var chat_modal = get_node_or_null("TableLayer/ChatMenuModal")
    if chat_btn and chat_modal:
        chat_btn.pressed.connect(func():
            chat_modal.visible = not chat_modal.visible
        )
        for i in range(1, 7):
            var btn = chat_modal.get_node_or_null("ChatList/ChatBtn%d" % i)
            if btn:
                btn.pressed.connect(func():
                    chat_modal.visible = false
                    show_player_speech(btn.text)
                    var mgr = get_node_or_null("/root/Main/BurracoGameManager")
                    if mgr and mgr.has_method("on_player_sent_chat"):
                        mgr.on_player_sent_chat(btn.text)
                )

    # Navigation setup
    if tab_home_btn:
        tab_home_btn.pressed.connect(_return_to_main_menu)
    tab_table_btn.pressed.connect(func(): switch_tab(0))
    tab_box_btn.pressed.connect(func(): switch_tab(1))
    tab_club_btn.pressed.connect(func(): switch_tab(2))

    if sound_btn:
        sound_btn.pressed.connect(func():
            var audio = get_node_or_null("/root/AudioSynth")
            if audio:
                var is_muted = audio.toggle_mute()
                sound_btn.text = "🔇" if is_muted else "🔊"
        )

    # Initial state: hide in-game layers and open directly on the Home Screen!
    header_bar.visible = false
    table_layer.visible = false
    blind_box_layer.visible = false
    club_layer.visible = false

    _build_main_menu()
    _build_rules_modal()
    _build_story_modal()
    _build_online_modal()

    # Process command line testing flags
    _check_cli_args()

func _process(delta: float) -> void:
    menu_anim_time += delta
    
    # 1. Subtle breathing animation for Menu Logo (gentle Pixar pulse)
    if menu_logo != null and main_menu_layer != null and main_menu_layer.visible:
        var s = 1.0 + sin(menu_anim_time * 2.2) * 0.018
        menu_logo.scale = Vector2(s, s)
        menu_logo.pivot_offset = menu_logo.size / 2.0

    # 2. Pulsing golden glow for Burraco Veloce hero button
    if quick_play_btn != null and main_menu_layer != null and main_menu_layer.visible:
        var pulse = (sin(menu_anim_time * 4.5) + 1.0) * 0.5
        var border_col = Color(1.0, 0.82 + pulse * 0.18, 0.20 + pulse * 0.35, 1.0)
        var sb = quick_play_btn.get_theme_stylebox("normal")
        if sb is StyleBoxFlat:
            sb.border_color = border_col

# ==============================================================================
# 1. MAIN MENU (MEDIEVAL TAVERN PIXAR/CLASH + 4 GRANDI BOTTONI IN GRIGLIA)
# ==============================================================================
func _build_main_menu() -> void:
    main_menu_layer = Control.new()
    main_menu_layer.name = "MainMenuLayer"
    main_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_menu_layer.z_index = 35
    add_child(main_menu_layer)

    # 1. Medieval Tavern Background (Pixar & Clash Royale 3D Style)
    var bg_img = TextureRect.new()
    bg_img.name = "MedievalBackground"
    bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg_img.texture = AssetLoader.get_tex("res://assets/menu_bg_medieval.png")
    if bg_img.texture == null:
        bg_img.texture = AssetLoader.get_tex("res://assets/menu_bg_medieval.jpg")
    bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    main_menu_layer.add_child(bg_img)

    # 2. Vignette / Warm Scrim for Maximum UI Contrast
    var scrim = ColorRect.new()
    scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
    scrim.color = Color(0.02, 0.01, 0.01, 0.20)
    main_menu_layer.add_child(scrim)

    # 3. Responsive Center Container (Centers perfectly on every phone & tablet)
    var center_container = CenterContainer.new()
    center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_menu_layer.add_child(center_container)

    # 4. Main Content Vertical Box (Portrait 720 x 1280)
    var main_vbox = VBoxContainer.new()
    main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    main_vbox.custom_minimum_size = Vector2(650, 0)
    main_vbox.add_theme_constant_override("separation", 20)
    center_container.add_child(main_vbox)

    # 5. Top 3D Pixar/Clash Logo (Clean, centered, floating, majestic in portrait)
    menu_logo = TextureRect.new()
    menu_logo.custom_minimum_size = Vector2(580, 180)
    menu_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    menu_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_splash.png")
    if menu_logo.texture == null:
        menu_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_transparent.png")
    if menu_logo.texture == null:
        menu_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_aaa.png")
    main_vbox.add_child(menu_logo)

    # 6. 4 GRANDI BOTTONI VERTICALI (Larghi 640px, Alti 135px, distanziati per riempire lo schermo)
    var btn_box = VBoxContainer.new()
    btn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn_box.add_theme_constant_override("separation", 18)
    main_vbox.add_child(btn_box)

    # BUTTON 1: STORIA
    var btn_story = _create_huge_card_button(
        "⚔️",
        "STORIA",
        "Campagna Roguelike & Sfide nei Club",
        "✦ ATTO I DISPONIBILE ✦",
        Color(0.10, 0.20, 0.44, 0.98),
        Color(0.92, 0.78, 0.35, 1.0)
    )
    btn_story.pressed.connect(_on_btn_story_pressed)
    btn_box.add_child(btn_story)

    # BUTTON 2: BURRACO VELOCE (PRIMARY HERO BUTTON - CLASH STYLE GOLD)
    quick_play_btn = _create_huge_card_button(
        "🃏",
        "BURRACO VELOCE",
        "Partita Rapida Tradizionale F.I.BUR 1v1",
        "⭐ GIOCA SUBITO ⭐",
        Color(0.72, 0.42, 0.04, 0.98),
        Color(1.0, 0.88, 0.28, 1.0),
        true
    )
    quick_play_btn.pressed.connect(_start_quick_game)
    btn_box.add_child(quick_play_btn)

    # BUTTON 3: ONLINE
    var btn_online = _create_huge_card_button(
        "🌐",
        "ONLINE",
        "Tornei, Classificate & Stanze con Amici",
        "✦ MULTIPLAYER F.I.BUR ✦",
        Color(0.08, 0.36, 0.22, 0.98),
        Color(0.42, 0.95, 0.68, 1.0)
    )
    btn_online.pressed.connect(_on_btn_online_pressed)
    btn_box.add_child(btn_online)

    # BUTTON 4: REGOLE
    var btn_rules = _create_huge_card_button(
        "📜",
        "REGOLE",
        "Manuale Ufficiale, Burrachi & Punteggi",
        "✦ GUIDA UFFICIALE ✦",
        Color(0.46, 0.12, 0.08, 0.98),
        Color(1.0, 0.76, 0.45, 1.0)
    )
    btn_rules.pressed.connect(_show_rules_modal)
    btn_box.add_child(btn_rules)

    # 7. Subdued Golden Footer
    var footer = Label.new()
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.text = "✦  BURRACO KINGDOM  •  EDIZIONE UFFICIALE F.I.BUR  •  v1.0.0 MOBILE  ✦"
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 0.80))
    main_vbox.add_child(footer)

func _create_huge_card_button(icon_emoji: String, title: String, subtitle: String, tag: String, bg_col: Color, border_col: Color, is_primary: bool = false) -> Button:
    var btn = Button.new()
    # MASSIVE SIZE: 570px wide x 190px tall (more than 2.5x larger than before!)
    btn.custom_minimum_size = Vector2(640, 136)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    # 3D Clash Royale style bevel with heavy shadow and thick shiny border
    var sb = StyleBoxFlat.new()
    sb.bg_color = bg_col
    sb.border_color = border_col
    sb.border_width_left = 5 if is_primary else 4
    sb.border_width_top = 5 if is_primary else 4
    sb.border_width_right = 5 if is_primary else 4
    sb.border_width_bottom = 8 if is_primary else 6
    sb.corner_radius_top_left = 22
    sb.corner_radius_top_right = 22
    sb.corner_radius_bottom_right = 22
    sb.corner_radius_bottom_left = 22
    sb.shadow_color = Color(0, 0, 0, 0.75)
    sb.shadow_size = 10
    sb.shadow_offset = Vector2(0, 7)
    btn.add_theme_stylebox_override("normal", sb)

    var sb_hover = sb.duplicate()
    sb_hover.bg_color = bg_col.lightened(0.14)
    sb_hover.border_color = border_col.lightened(0.2)
    sb_hover.shadow_offset = Vector2(0, 9)
    btn.add_theme_stylebox_override("hover", sb_hover)

    var sb_pressed = sb.duplicate()
    sb_pressed.bg_color = bg_col.darkened(0.12)
    sb_pressed.shadow_offset = Vector2(0, 2)
    btn.add_theme_stylebox_override("pressed", sb_pressed)

    # Content Container inside the button
    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_theme_constant_override("separation", 18)
    hbox.offset_left = 24
    hbox.offset_right = -24
    hbox.offset_top = 16
    hbox.offset_bottom = -16
    btn.add_child(hbox)

    # Left: Giant Icon Badge
    var icon_lbl = Label.new()
    icon_lbl.text = icon_emoji
    icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon_lbl.add_theme_font_size_override("font_size", 48)
    hbox.add_child(icon_lbl)

    # Right: Text Stack
    var vbox = VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_theme_constant_override("separation", 4)
    hbox.add_child(vbox)

    # Badge tag (e.g. "⭐ GIOCA SUBITO ⭐")
    var l_tag = Label.new()
    l_tag.text = tag
    l_tag.add_theme_font_size_override("font_size", 11)
    l_tag.add_theme_color_override("font_color", border_col.lightened(0.25))
    vbox.add_child(l_tag)

    # Big Title
    var l_title = Label.new()
    l_title.text = title
    l_title.add_theme_font_size_override("font_size", 30 if is_primary else 28)
    l_title.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90) if is_primary else Color(1.0, 1.0, 1.0))
    vbox.add_child(l_title)

    # Subtitle
    var l_sub = Label.new()
    l_sub.text = subtitle
    l_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l_sub.add_theme_font_size_override("font_size", 13)
    l_sub.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.95))
    vbox.add_child(l_sub)

    return btn

# ==============================================================================
# 2. GAME TRANSITIONS & MODALS
# ==============================================================================
func _start_quick_game() -> void:
    current_state = UIState.IN_GAME
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()

    var tw = create_tween()
    tw.tween_property(main_menu_layer, "modulate:a", 0.0, 0.30)
    tw.tween_callback(func():
        main_menu_layer.visible = false
        header_bar.visible = true
        table_layer.visible = true
        blind_box_layer.visible = false
        club_layer.visible = false
        switch_tab(0)
    )

func _return_to_main_menu() -> void:
    current_state = UIState.MAIN_MENU
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()

    header_bar.visible = false
    table_layer.visible = false
    blind_box_layer.visible = false
    club_layer.visible = false

    main_menu_layer.modulate.a = 0.0
    main_menu_layer.visible = true
    var tw = create_tween()
    tw.tween_property(main_menu_layer, "modulate:a", 1.0, 0.30)

func _on_btn_story_pressed() -> void:
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()
    _refresh_story_roster()
    if story_modal:
        story_modal.visible = true

## Chiude il roster e avvia una sfida della Storia contro il villain scelto.
func _start_campaign_fight(villain: CampaignVillain) -> void:
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()
    if story_modal:
        story_modal.visible = false

    current_state = UIState.IN_GAME
    var tw = create_tween()
    tw.tween_property(main_menu_layer, "modulate:a", 0.0, 0.30)
    tw.tween_callback(func():
        main_menu_layer.visible = false
        header_bar.visible = true
        table_layer.visible = true
        blind_box_layer.visible = false
        club_layer.visible = false
        switch_tab(0)
        var mgr = get_node_or_null("/root/Main/BurracoGameManager")
        if mgr and mgr.has_method("start_campaign_match"):
            mgr.start_campaign_match(villain)
    )

func _on_btn_online_pressed() -> void:
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()
    if online_modal:
        online_modal.visible = true

func _show_rules_modal() -> void:
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()
    if rules_modal:
        rules_modal.visible = true

# ==============================================================================
# 3. RULES MODAL (MANUALE UFFICIALE F.I.BUR)
# ==============================================================================
func _build_rules_modal() -> void:
    rules_modal = Control.new()
    rules_modal.name = "RulesModal"
    rules_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    rules_modal.z_index = 60
    rules_modal.visible = false
    add_child(rules_modal)

    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.75)
    rules_modal.add_child(bg)

    var center_c = CenterContainer.new()
    center_c.set_anchors_preset(Control.PRESET_FULL_RECT)
    rules_modal.add_child(center_c)

    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(680, 920)
    var psb = StyleBoxFlat.new()
    psb.bg_color = Color(0.06, 0.09, 0.12, 0.98)
    psb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    psb.set_border_width_all(3)
    psb.corner_radius_top_left = 14
    psb.corner_radius_top_right = 14
    psb.corner_radius_bottom_right = 14
    psb.corner_radius_bottom_left = 14
    psb.shadow_size = 14
    psb.shadow_color = Color(0, 0, 0, 0.65)
    panel.add_theme_stylebox_override("panel", psb)
    center_c.add_child(panel)

    var title = Label.new()
    title.text = "📜 REGOLAMENTO UFFICIALE F.I.BUR"
    title.position = Vector2(30, 18)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
    panel.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "✖ CHIUDI"
    close_btn.custom_minimum_size = Vector2(100, 36)
    close_btn.position = Vector2(980 - 130, 16)
    var csb = StyleBoxFlat.new()
    csb.bg_color = Color(0.22, 0.1, 0.12, 0.9)
    csb.border_color = Color(0.9, 0.4, 0.4, 1.0)
    csb.set_border_width_all(2)
    csb.set_corner_radius_all(6)
    close_btn.add_theme_stylebox_override("normal", csb)
    close_btn.pressed.connect(func(): rules_modal.visible = false)
    panel.add_child(close_btn)

    var cards_box = HBoxContainer.new()
    cards_box.position = Vector2(25, 70)
    cards_box.size = Vector2(640, 800)
    cards_box.add_theme_constant_override("separation", 15)
    panel.add_child(cards_box)

    var card1 = _create_rule_card(
        "🏆 I BURRACHI (7+ Carte)",
        Color(0.12, 0.18, 0.14, 0.95),
        Color(0.3, 0.85, 0.5, 1.0),
        "🌟 BURRACO PULITO (+200 pt)\nSequenza di 7+ carte dello stesso seme senza Pinelle né Jolly.\n\n" +
        "🔥 BURRACO SEMIPULITO (+150 pt)\nSequenza di almeno 7 o 8 carte con un 2 nella sua posizione naturale o Pinella legata a capo.\n\n" +
        "💎 BURRACO SPORCO (+100 pt)\nSequenza di 7+ carte che impiega una Pinella o un Jolly come sostituto generico."
    )
    cards_box.add_child(card1)

    var card2 = _create_rule_card(
        "🃏 CARTE & POZZETTO",
        Color(0.15, 0.14, 0.22, 0.95),
        Color(0.6, 0.75, 1.0, 1.0),
        "🦆 PINELLA (Tutti i 2)\nVale 20 punti. Può sostituire qualsiasi carta oppure fungere da 2 naturale nel proprio seme.\n\n" +
        "🃏 JOLLY (Joker)\nVale 30 punti. Una sola carta speciale è consentita per ogni combinazione o scala.\n\n" +
        "🏺 IL POZZETTO (11 Carte)\nSi raccoglie quando finisci la mano iniziale. Se non viene preso prima della chiusura avversaria: -100 pt!"
    )
    cards_box.add_child(card2)

    var card3 = _create_rule_card(
        "⚡ CHIUSURA & PUNTI",
        Color(0.20, 0.15, 0.10, 0.95),
        Color(1.0, 0.75, 0.3, 1.0),
        "🏁 REQUISITI PER CHIUDERE:\n1. Aver raccolto il Pozzetto.\n2. Aver completato almeno un Burraco (Pulito, Semipulito o Sporco).\n3. Scartare l'ultima carta sul monte scarti.\n\n" +
        "⭐ BONUS & PENALITÀ:\n• Bonus Chiusura: +100 pt\n• Carte in mano non calate: SOTTRATTE dal punteggio finale!\n• Partita vinta al raggiungimento di 1,005 o 2,005 pt."
    )
    cards_box.add_child(card3)

func _create_rule_card(header_text: String, bg_col: Color, border_col: Color, body_text: String) -> Panel:
    var p = Panel.new()
    p.custom_minimum_size = Vector2(300, 480)
    var sb = StyleBoxFlat.new()
    sb.bg_color = bg_col
    sb.border_color = border_col
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(8)
    p.add_theme_stylebox_override("panel", sb)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.offset_left = 15
    vbox.offset_top = 15
    vbox.offset_right = -15
    vbox.offset_bottom = -15
    p.add_child(vbox)

    var hl = Label.new()
    hl.text = header_text
    hl.add_theme_font_size_override("font_size", 16)
    hl.add_theme_color_override("font_color", border_col)
    vbox.add_child(hl)

    var sep = HSeparator.new()
    vbox.add_child(sep)

    var body = Label.new()
    body.text = body_text
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", 13)
    body.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
    vbox.add_child(body)

    return p

# ==============================================================================
# 4. STORY ROSTER (MONDO 1: LA TAVERNA DEI QUATTRO ASSI) & ONLINE PREVIEW MODAL
# ==============================================================================
func _build_story_modal() -> void:
    story_modal = Control.new()
    story_modal.name = "StoryModal"
    story_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    story_modal.z_index = 60
    story_modal.visible = false
    add_child(story_modal)

    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.78)
    story_modal.add_child(bg)

    var center_c = CenterContainer.new()
    center_c.set_anchors_preset(Control.PRESET_FULL_RECT)
    story_modal.add_child(center_c)

    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(660, 1080)
    var psb = StyleBoxFlat.new()
    psb.bg_color = Color(0.07, 0.06, 0.10, 0.98)
    psb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    psb.set_border_width_all(3)
    psb.set_corner_radius_all(14)
    psb.shadow_size = 14
    psb.shadow_color = Color(0, 0, 0, 0.65)
    panel.add_theme_stylebox_override("panel", psb)
    center_c.add_child(panel)

    var title = Label.new()
    title.text = "⚔️ MONDO 1: LA TAVERNA DEI QUATTRO ASSI"
    title.position = Vector2(24, 16)
    title.size = Vector2(660 - 130, 26)
    title.add_theme_font_size_override("font_size", 17)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
    panel.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "✖"
    close_btn.custom_minimum_size = Vector2(40, 36)
    close_btn.position = Vector2(660 - 24 - 40, 14)
    var csb = StyleBoxFlat.new()
    csb.bg_color = Color(0.22, 0.1, 0.12, 0.9)
    csb.border_color = Color(0.9, 0.4, 0.4, 1.0)
    csb.set_border_width_all(2)
    csb.set_corner_radius_all(6)
    close_btn.add_theme_stylebox_override("normal", csb)
    close_btn.pressed.connect(func(): story_modal.visible = false)
    panel.add_child(close_btn)

    var sub = Label.new()
    sub.text = "Sfida i 9 avventori e il Signore della Taverna, nell'ordine. Ogni vittoria sblocca il prossimo."
    sub.position = Vector2(24, 46)
    sub.size = Vector2(660 - 48, 32)
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", 12)
    sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.85, 1.0))
    panel.add_child(sub)

    var scroll = ScrollContainer.new()
    scroll.position = Vector2(20, 82)
    scroll.size = Vector2(660 - 40, 1080 - 82 - 16)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)

    story_roster_list = VBoxContainer.new()
    story_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    story_roster_list.add_theme_constant_override("separation", 10)
    scroll.add_child(story_roster_list)

## Ricostruisce la lista dei villain leggendo lo stato di sblocco dal game manager.
func _refresh_story_roster() -> void:
    if story_roster_list == null: return
    for c in story_roster_list.get_children():
        c.queue_free()

    var mgr = get_node_or_null("/root/Main/BurracoGameManager")
    var defeated: Dictionary = {}
    if mgr and "defeated_villain_ids" in mgr:
        defeated = mgr.defeated_villain_ids

    var roster = CampaignVillain.get_world_1_roster()
    for i in range(roster.size()):
        var v: CampaignVillain = roster[i]
        var is_defeated = defeated.has(v.id)
        var is_unlocked = i == 0 or defeated.has(roster[i - 1].id)
        story_roster_list.add_child(_create_villain_row(v, is_unlocked, is_defeated, i))

# Icone per i villain non-boss (l'Apex Dragon è riservato al Signore della Taverna),
# assegnate a rotazione così il roster non mostra la stessa faccia per tutti.
const VILLAIN_AVATARS: Array[String] = [
    "res://assets/creature_solar_sphinx.png",
    "res://assets/suit_hearts.png",
    "res://assets/creature_cyber_pinella.png",
    "res://assets/suit_clubs.png",
    "res://assets/creature_neon_chimera.png",
    "res://assets/suit_diamonds.png",
    "res://assets/suit_spades.png",
    "res://assets/suit_joker.png",
]

func _create_villain_row(v: CampaignVillain, is_unlocked: bool, is_defeated: bool, avatar_index: int) -> Control:
    var row = Panel.new()
    row.custom_minimum_size = Vector2(0, 92)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var rsb = StyleBoxFlat.new()
    rsb.bg_color = Color(0.30, 0.10, 0.32, 0.95) if v.is_boss else Color(0.12, 0.13, 0.18, 0.92)
    rsb.border_color = Color(0.96, 0.82, 0.25, 1.0) if v.is_boss else Color(0.32, 0.34, 0.42, 0.9)
    rsb.set_border_width_all(2 if v.is_boss else 1)
    rsb.set_corner_radius_all(10)
    if not is_unlocked:
        rsb.bg_color = rsb.bg_color.darkened(0.55)
    row.add_theme_stylebox_override("panel", rsb)

    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.offset_left = 12
    hbox.offset_right = -12
    hbox.offset_top = 8
    hbox.offset_bottom = -8
    hbox.add_theme_constant_override("separation", 12)
    row.add_child(hbox)

    var avatar = TextureRect.new()
    avatar.custom_minimum_size = Vector2(64, 64)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var dedicated_avatar = AssetLoader.get_tex("res://assets/villain_%s.png" % v.id)
    if dedicated_avatar != null:
        avatar.texture = dedicated_avatar
    elif v.is_boss:
        avatar.texture = AssetLoader.get_tex("res://assets/creature_apex_dragon.png")
    else:
        avatar.texture = AssetLoader.get_tex(VILLAIN_AVATARS[avatar_index % VILLAIN_AVATARS.size()])
    if not is_unlocked:
        avatar.modulate = Color(1, 1, 1, 0.35)
    hbox.add_child(avatar)

    var vbox = VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    vbox.add_theme_constant_override("separation", 2)
    hbox.add_child(vbox)

    var name_lbl = Label.new()
    name_lbl.text = ("👑 " if v.is_boss else "") + v.display_name
    name_lbl.add_theme_font_size_override("font_size", 15)
    name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if v.is_boss else Color(0.95, 0.95, 0.95))
    vbox.add_child(name_lbl)

    var epithet_lbl = Label.new()
    epithet_lbl.text = v.epithet
    epithet_lbl.add_theme_font_size_override("font_size", 11)
    epithet_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
    vbox.add_child(epithet_lbl)

    var flavor_lbl = Label.new()
    flavor_lbl.text = v.flavor_line if is_unlocked else "Sconfiggi lo sfidante precedente per affrontarlo."
    flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    flavor_lbl.add_theme_font_size_override("font_size", 10)
    flavor_lbl.add_theme_color_override("font_color", Color(0.68, 0.66, 0.72))
    vbox.add_child(flavor_lbl)

    var diff_lbl = Label.new()
    var pips = int(round(v.difficulty * 10.0))
    diff_lbl.text = "DIFFICOLTÀ  " + "●".repeat(pips) + "○".repeat(10 - pips)
    diff_lbl.add_theme_font_size_override("font_size", 9)
    diff_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3) if pips >= 8 else Color(0.6, 0.75, 0.6))
    vbox.add_child(diff_lbl)

    var action_box = VBoxContainer.new()
    action_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    action_box.custom_minimum_size = Vector2(96, 0)
    action_box.add_theme_constant_override("separation", 4)
    hbox.add_child(action_box)

    if is_defeated:
        var tag = Label.new()
        tag.text = "✓ SUPERATO"
        tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tag.add_theme_font_size_override("font_size", 10)
        tag.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
        action_box.add_child(tag)

    var btn = Button.new()
    btn.custom_minimum_size = Vector2(96, 36)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    if is_unlocked:
        btn.text = "RIVINCITA" if is_defeated else "SFIDA"
        var bsb = StyleBoxFlat.new()
        bsb.bg_color = Color(0.72, 0.42, 0.04, 0.98) if not v.is_boss else Color(0.55, 0.12, 0.58, 0.98)
        bsb.border_color = Color(1.0, 0.88, 0.28, 1.0)
        bsb.set_border_width_all(2)
        bsb.set_corner_radius_all(8)
        btn.add_theme_stylebox_override("normal", bsb)
        btn.add_theme_font_size_override("font_size", 11)
        btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
        btn.pressed.connect(func(): _start_campaign_fight(v))
    else:
        btn.text = "🔒"
        btn.disabled = true
        var lsb = StyleBoxFlat.new()
        lsb.bg_color = Color(0.15, 0.15, 0.18, 0.8)
        lsb.border_color = Color(0.35, 0.35, 0.4, 0.8)
        lsb.set_border_width_all(1)
        lsb.set_corner_radius_all(8)
        btn.add_theme_stylebox_override("disabled", lsb)
    action_box.add_child(btn)

    return row

func _build_online_modal() -> void:
    online_modal = _create_info_dialog(
        "🌐 MULTIPLAYER ONLINE: LADDER CLASSIFICATA",
        "⚡ SERVER DI GIOCO STAGIONE 1\n\n" +
        "Sfida giocatori reali da tutta Italia nel circuito competitivo ufficiale!\n\n" +
        "• Partite 1v1 e 2v2 a coppie con timer F.I.BUR.\n" +
        "• Classifica ELO e Titoli di Gran Maestro del Burraco.\n" +
        "• Stanze Private con codice per giocare comodamente con gli amici.\n\n" +
        "I server multiplayer apriranno a breve!"
    )

func _create_info_dialog(title_text: String, content_text: String) -> Control:
    var modal = Control.new()
    modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    modal.z_index = 60
    modal.visible = false
    add_child(modal)

    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.75)
    modal.add_child(bg)

    var center_c = CenterContainer.new()
    center_c.set_anchors_preset(Control.PRESET_FULL_RECT)
    modal.add_child(center_c)

    var p = Panel.new()
    p.custom_minimum_size = Vector2(620, 360)
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.11, 0.15, 0.98)
    sb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(10)
    p.add_theme_stylebox_override("panel", sb)
    center_c.add_child(p)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.offset_left = 25
    vbox.offset_top = 20
    vbox.offset_right = -25
    vbox.offset_bottom = -20
    p.add_child(vbox)

    var t = Label.new()
    t.text = title_text
    t.add_theme_font_size_override("font_size", 18)
    t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
    vbox.add_child(t)

    vbox.add_child(HSeparator.new())

    var c = Label.new()
    c.text = content_text
    c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    c.add_theme_font_size_override("font_size", 13)
    c.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1.0))
    vbox.add_child(c)

    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)

    var ok_btn = Button.new()
    ok_btn.text = "CHIUDI"
    ok_btn.custom_minimum_size = Vector2(120, 36)
    ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var bsb = StyleBoxFlat.new()
    bsb.bg_color = Color(0.18, 0.22, 0.3, 0.95)
    bsb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    bsb.set_border_width_all(2)
    bsb.set_corner_radius_all(6)
    ok_btn.add_theme_stylebox_override("normal", bsb)
    ok_btn.pressed.connect(func(): modal.visible = false)
    vbox.add_child(ok_btn)

    return modal

# ==============================================================================
# 5. TAB SWITCHING (IN-GAME)
# ==============================================================================
func switch_tab(tab_idx: int) -> void:
    if current_state != UIState.IN_GAME:
        return
    table_layer.visible = (tab_idx == 0)
    blind_box_layer.visible = (tab_idx == 1)
    club_layer.visible = (tab_idx == 2)
    tab_table_btn.button_pressed = (tab_idx == 0)
    tab_box_btn.button_pressed = (tab_idx == 1)
    tab_club_btn.button_pressed = (tab_idx == 2)

    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()

func _check_cli_args() -> void:
    var args = OS.get_cmdline_args()
    for arg in args:
        if "test-melds" in arg:
            get_tree().create_timer(0.3).timeout.connect(func():
                _start_quick_game()
                var mgr = get_node_or_null("/root/Main/BurracoGameManager")
                if mgr:
                    var CardData = preload("res://scripts/card_data.gd")
                    var Rules = preload("res://scripts/rules.gd")
                    var m1 = Rules.BurracoMeld.new()
                    m1.type = Rules.MeldType.SEQUENCE
                    m1.suit = CardData.Suit.SPADES
                    for r in [CardData.Rank.THREE, CardData.Rank.FOUR, CardData.Rank.FIVE, CardData.Rank.SIX, CardData.Rank.SEVEN, CardData.Rank.EIGHT, CardData.Rank.NINE]:
                        m1.cards.append(CardData.create_card(100 + r, CardData.Suit.SPADES, r))
                    mgr.player_melds.append(m1)

                    var m3 = Rules.BurracoMeld.new()
                    m3.type = Rules.MeldType.SEQUENCE
                    m3.suit = CardData.Suit.HEARTS
                    var j_card = CardData.create_card(300, CardData.Suit.JOKER, CardData.Rank.NONE, 0, true)
                    m3.cards.append(j_card)
                    for r in [CardData.Rank.FOUR, CardData.Rank.FIVE, CardData.Rank.SIX, CardData.Rank.SEVEN, CardData.Rank.EIGHT, CardData.Rank.NINE]:
                        m3.cards.append(CardData.create_card(300 + r, CardData.Suit.HEARTS, r))
                    mgr.opponent_melds.append(m3)

                    # Sample cards in discard pile for testing swipeable strip
                    mgr.deck.discard_pile.append(CardData.create_card(205, CardData.Suit.DIAMONDS, CardData.Rank.FIVE))
                    mgr.deck.discard_pile.append(CardData.create_card(206, CardData.Suit.DIAMONDS, CardData.Rank.SIX))
                    mgr.deck.discard_pile.append(CardData.create_card(108, CardData.Suit.SPADES, CardData.Rank.EIGHT))
                    mgr.deck.discard_pile.append(CardData.create_card(402, CardData.Suit.CLUBS, CardData.Rank.TWO, 0, false))

                    mgr.refresh_all_ui()
            )

        if "test-game" in arg:
            get_tree().create_timer(0.3).timeout.connect(func():
                _start_quick_game()
            )

        if "test-campaign" in arg:
            get_tree().create_timer(0.3).timeout.connect(func():
                var roster = CampaignVillain.get_world_1_roster()
                _start_campaign_fight(roster[0])
                get_tree().create_timer(0.6).timeout.connect(func():
                    var img = get_viewport().get_texture().get_image()
                    var p = ProjectSettings.globalize_path("res://assets/campaign_screenshot.png")
                    img.save_png(p)
                    print("CAMPAIGN_SCREENSHOT_SAVED: ", p)
                    get_tree().quit()
                )
            )

        if "test-menu" in arg:
            get_tree().create_timer(0.4).timeout.connect(func():
                var img = get_viewport().get_texture().get_image()
                var p = ProjectSettings.globalize_path("res://assets/menu_screenshot.png")
                img.save_png(p)
                print("MENU_SCREENSHOT_SAVED: ", p)
                get_tree().quit()
            )

        if "test-story" in arg:
            get_tree().create_timer(0.4).timeout.connect(func():
                _on_btn_story_pressed()
                get_tree().create_timer(0.3).timeout.connect(func():
                    var img = get_viewport().get_texture().get_image()
                    var p = ProjectSettings.globalize_path("res://assets/story_screenshot.png")
                    img.save_png(p)
                    print("STORY_SCREENSHOT_SAVED: ", p)
                    get_tree().quit()
                )
            )

        if "screenshot" in arg:
            get_tree().create_timer(1.2).timeout.connect(func():
                var img = get_viewport().get_texture().get_image()
                var p = ProjectSettings.globalize_path("res://assets/game_screenshot.png")
                img.save_png(p)
                print("SCREENSHOT_SAVED: ", p)
                get_tree().quit()
            )

func show_player_speech(msg_text: String) -> void:
    var bubble = get_node_or_null("TableLayer/SpeechBubblePlayer")
    var lbl = get_node_or_null("TableLayer/SpeechBubblePlayer/SpeechBubblePlayerLabel")
    if bubble and lbl:
        lbl.text = msg_text
        bubble.visible = true
        bubble.modulate.a = 1.0
        var audio = get_node_or_null("/root/AudioSynth")
        if audio and audio.has_method("play_chat_pop"):
            audio.play_chat_pop()
        var tw = create_tween()
        tw.tween_interval(2.5)
        tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
        tw.tween_callback(func(): bubble.visible = false)

func show_opp_speech(msg_text: String) -> void:
    var bubble = get_node_or_null("TableLayer/SpeechBubbleOpp")
    var lbl = get_node_or_null("TableLayer/SpeechBubbleOpp/SpeechBubbleOppLabel")
    if bubble and lbl:
        lbl.text = msg_text
        bubble.visible = true
        bubble.modulate.a = 1.0
        var audio = get_node_or_null("/root/AudioSynth")
        if audio and audio.has_method("play_chat_pop"):
            audio.play_chat_pop()
        var tw = create_tween()
        tw.tween_interval(2.8)
        tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
        tw.tween_callback(func(): bubble.visible = false)
