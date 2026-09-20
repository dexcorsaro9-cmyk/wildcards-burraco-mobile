class_name MainUI
extends CanvasLayer

const AssetLoader = preload("res://scripts/asset_loader.gd")

enum UIState { SPLASH, MAIN_MENU, IN_GAME }
var current_state: UIState = UIState.SPLASH

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

# Dynamic Layers
var splash_layer: Control
var splash_logo: TextureRect
var splash_prompt: Label
var splash_timer: SceneTreeTimer

var main_menu_layer: Control
var menu_logo: TextureRect
var quick_play_btn: Button
var menu_anim_time: float = 0.0

var rules_modal: Control
var story_modal: Control
var online_modal: Control

func _ready() -> void:
    if bg_texture_rect:
        bg_texture_rect.texture = AssetLoader.get_tex("res://assets/table_felt_luxury.png")

    if stock_btn is TextureButton:
        stock_btn.texture_normal = AssetLoader.get_tex("res://assets/card_back_luxury.png")

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

    # Initial state: hide game layers and build Splash & Menu
    header_bar.visible = false
    table_layer.visible = false
    blind_box_layer.visible = false
    club_layer.visible = false

    _build_splash_screen()
    _build_main_menu()
    _build_rules_modal()
    _build_story_modal()
    _build_online_modal()

    _show_splash()

    # Process command line testing flags
    _check_cli_args()

func _process(delta: float) -> void:
    menu_anim_time += delta
    
    # 1. Floating animation for Menu Logo
    if menu_logo != null and main_menu_layer != null and main_menu_layer.visible:
        menu_logo.position.y = 12.0 + sin(menu_anim_time * 2.2) * 5.0

    # 2. Pulsing glow for Quick Play button
    if quick_play_btn != null and main_menu_layer != null and main_menu_layer.visible:
        var pulse = (sin(menu_anim_time * 4.0) + 1.0) * 0.5
        var border_col = Color(0.96, 0.78 + pulse * 0.18, 0.22 + pulse * 0.25, 1.0)
        var sb = quick_play_btn.get_theme_stylebox("normal")
        if sb is StyleBoxFlat:
            sb.border_color = border_col

    # 3. Splash prompt blink
    if splash_prompt != null and splash_layer != null and splash_layer.visible:
        var alpha = 0.45 + (sin(menu_anim_time * 4.5) + 1.0) * 0.275
        splash_prompt.modulate.a = alpha

# ==============================================================================
# 1. SPLASH SCREEN
# ==============================================================================
func _build_splash_screen() -> void:
    splash_layer = Control.new()
    splash_layer.name = "SplashLayer"
    splash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    splash_layer.z_index = 50
    add_child(splash_layer)

    # Dark luxury vignette overlay
    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.02, 0.03, 0.04, 1.0)
    splash_layer.add_child(bg)

    # Central Logo Pixar / Clash Style (Massive and bold)
    splash_logo = TextureRect.new()
    splash_logo.set_anchors_preset(Control.PRESET_CENTER)
    splash_logo.custom_minimum_size = Vector2(1100, 615)
    splash_logo.size = Vector2(1100, 615)
    splash_logo.position = Vector2((1280 - 1100) / 2.0, (720 - 615) / 2.0 - 15.0)
    splash_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    splash_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    splash_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_aaa.png")
    splash_logo.modulate.a = 0.0
    splash_layer.add_child(splash_logo)

    # Tap prompt
    splash_prompt = Label.new()
    splash_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    splash_prompt.offset_top = -65.0
    splash_prompt.offset_bottom = -25.0
    splash_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    splash_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    splash_prompt.text = "✦  TOCCA PER ENTRARE NEL CLUB  ✦"
    splash_prompt.add_theme_font_size_override("font_size", 16)
    splash_prompt.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
    splash_prompt.modulate.a = 0.0
    splash_layer.add_child(splash_prompt)

    # Make whole splash clickable to skip
    splash_layer.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            _exit_splash_to_menu()
    )

func _show_splash() -> void:
    current_state = UIState.SPLASH
    splash_layer.visible = true
    main_menu_layer.visible = false

    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_splash_jingle"):
        audio.play_splash_jingle()

    var tw = create_tween().set_parallel(true)
    tw.tween_property(splash_logo, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(splash_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    splash_timer = get_tree().create_timer(3.2)
    splash_timer.timeout.connect(func():
        if current_state == UIState.SPLASH:
            _exit_splash_to_menu()
    )

func _exit_splash_to_menu() -> void:
    if current_state != UIState.SPLASH: return
    current_state = UIState.MAIN_MENU

    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()

    var tw = create_tween()
    tw.tween_property(splash_layer, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        splash_layer.visible = false
        main_menu_layer.modulate.a = 0.0
        main_menu_layer.visible = true
        var tw2 = create_tween()
        tw2.tween_property(main_menu_layer, "modulate:a", 1.0, 0.35)
    )

# ==============================================================================
# 2. MAIN MENU (4 BUTTONS: STORIA, PARTITA RAPIDA, ONLINE, REGOLE)
# ==============================================================================
func _build_main_menu() -> void:
    main_menu_layer = Control.new()
    main_menu_layer.name = "MainMenuLayer"
    main_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_menu_layer.z_index = 35
    add_child(main_menu_layer)

    # Dark translucent felt overlay
    var overlay = ColorRect.new()
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.03, 0.07, 0.05, 0.88)
    main_menu_layer.add_child(overlay)

    # Top Emblem / Logo Badge
    menu_logo = TextureRect.new()
    menu_logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
    menu_logo.custom_minimum_size = Vector2(620, 260)
    menu_logo.size = Vector2(620, 260)
    menu_logo.position = Vector2((1280 - 620) / 2.0, 15.0)
    menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    menu_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_badge.png")
    if menu_logo.texture == null:
        menu_logo.texture = AssetLoader.get_tex("res://assets/logo_wildcards_aaa.png")
    main_menu_layer.add_child(menu_logo)

    # Center Buttons Container
    var btn_box = VBoxContainer.new()
    btn_box.set_anchors_preset(Control.PRESET_CENTER)
    btn_box.custom_minimum_size = Vector2(400, 310)
    btn_box.size = Vector2(400, 310)
    btn_box.position = Vector2((1280 - 400) / 2.0, 275.0)
    btn_box.add_theme_constant_override("separation", 11)
    main_menu_layer.add_child(btn_box)

    # 1. STORIA
    var btn_story = _create_menu_button("⚔️  STORIA", "Campagna Roguelike & Sfide nei Club", Color(0.12, 0.16, 0.26, 0.95), Color(0.5, 0.7, 0.95, 1.0))
    btn_story.pressed.connect(_on_btn_story_pressed)
    btn_box.add_child(btn_story)

    # 2. PARTITA RAPIDA (PRIMARY GOLD BUTTON)
    quick_play_btn = _create_menu_button("🃏  PARTITA RAPIDA", "Burraco Tradizionale F.I.BUR 1v1", Color(0.16, 0.13, 0.04, 0.98), Color(0.98, 0.82, 0.22, 1.0), true)
    quick_play_btn.pressed.connect(_start_quick_game)
    btn_box.add_child(quick_play_btn)

    # 3. ONLINE MULTIPLAYER
    var btn_online = _create_menu_button("🌐  ONLINE MULTIPLAYER", "Tornei, Classificate & Stanze Private", Color(0.08, 0.18, 0.14, 0.95), Color(0.4, 0.9, 0.7, 1.0))
    btn_online.pressed.connect(_on_btn_online_pressed)
    btn_box.add_child(btn_online)

    # 4. REGOLE
    var btn_rules = _create_menu_button("📜  REGOLE F.I.BUR", "Manuale Ufficiale, Burrachi & Punteggi", Color(0.18, 0.12, 0.08, 0.95), Color(0.95, 0.78, 0.5, 1.0))
    btn_rules.pressed.connect(_show_rules_modal)
    btn_box.add_child(btn_rules)

    # Bottom Footer Bar
    var footer = Label.new()
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_top = -32.0
    footer.offset_bottom = -8.0
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.text = "WILD-CARDS Burraco  •  Edizione Ufficiale F.I.BUR  •  v1.0.0 Mobile"
    footer.add_theme_font_size_override("font_size", 12)
    footer.add_theme_color_override("font_color", Color(0.65, 0.72, 0.75, 0.75))
    main_menu_layer.add_child(footer)

func _create_menu_button(title: String, subtitle: String, bg_col: Color, border_col: Color, is_primary: bool = false) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(400, 64)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    var sb = StyleBoxFlat.new()
    sb.bg_color = bg_col
    sb.border_color = border_col
    sb.border_width_left = 3 if is_primary else 2
    sb.border_width_top = 3 if is_primary else 2
    sb.border_width_right = 3 if is_primary else 2
    sb.border_width_bottom = 3 if is_primary else 2
    sb.corner_radius_top_left = 8
    sb.corner_radius_top_right = 8
    sb.corner_radius_bottom_right = 8
    sb.corner_radius_bottom_left = 8
    sb.shadow_color = Color(0, 0, 0, 0.5)
    sb.shadow_size = 4
    sb.shadow_offset = Vector2(0, 2)
    btn.add_theme_stylebox_override("normal", sb)

    var sb_hover = sb.duplicate()
    sb_hover.bg_color = bg_col.lightened(0.12)
    sb_hover.border_color = border_col.lightened(0.2)
    btn.add_theme_stylebox_override("hover", sb_hover)

    var sb_pressed = sb.duplicate()
    sb_pressed.bg_color = bg_col.darkened(0.1)
    btn.add_theme_stylebox_override("pressed", sb_pressed)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 2)
    btn.add_child(vbox)

    var l_title = Label.new()
    l_title.text = title
    l_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l_title.add_theme_font_size_override("font_size", 17 if is_primary else 16)
    l_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8) if is_primary else Color(0.95, 0.95, 0.95))
    vbox.add_child(l_title)

    var l_sub = Label.new()
    l_sub.text = subtitle
    l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l_sub.add_theme_font_size_override("font_size", 11)
    l_sub.add_theme_color_override("font_color", border_col.lightened(0.15))
    vbox.add_child(l_sub)

    return btn

# ==============================================================================
# 3. GAME TRANSITIONS & MODALS
# ==============================================================================
func _start_quick_game() -> void:
    current_state = UIState.IN_GAME
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()

    var tw = create_tween()
    tw.tween_property(main_menu_layer, "modulate:a", 0.0, 0.35)
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
    tw.tween_property(main_menu_layer, "modulate:a", 1.0, 0.35)

func _on_btn_story_pressed() -> void:
    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_menu_click"):
        audio.play_menu_click()
    if story_modal:
        story_modal.visible = true

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
# 4. RULES MODAL (MANUALE UFFICIALE F.I.BUR)
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

    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(980, 600)
    panel.size = Vector2(980, 600)
    panel.position = Vector2((1280 - 980) / 2.0, (720 - 600) / 2.0)
    var psb = StyleBoxFlat.new()
    psb.bg_color = Color(0.06, 0.09, 0.12, 0.98)
    psb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    psb.set_border_width_all(3)
    psb.corner_radius_top_left = 12
    psb.corner_radius_top_right = 12
    psb.corner_radius_bottom_right = 12
    psb.corner_radius_bottom_left = 12
    psb.shadow_size = 12
    psb.shadow_color = Color(0, 0, 0, 0.6)
    panel.add_theme_stylebox_override("panel", psb)
    rules_modal.add_child(panel)

    var title = Label.new()
    title.text = "📜 REGOLAMENTO UFFICIALE F.I.BUR"
    title.position = Vector2(30, 20)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
    panel.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "✖ CHIUDI"
    close_btn.custom_minimum_size = Vector2(100, 36)
    close_btn.position = Vector2(980 - 130, 18)
    var csb = StyleBoxFlat.new()
    csb.bg_color = Color(0.22, 0.1, 0.12, 0.9)
    csb.border_color = Color(0.9, 0.4, 0.4, 1.0)
    csb.set_border_width_all(2)
    csb.set_corner_radius_all(6)
    close_btn.add_theme_stylebox_override("normal", csb)
    close_btn.pressed.connect(func(): rules_modal.visible = false)
    panel.add_child(close_btn)

    var cards_box = HBoxContainer.new()
    cards_box.position = Vector2(25, 75)
    cards_box.size = Vector2(930, 490)
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
# 5. STORY & ONLINE PREVIEW MODALS
# ==============================================================================
func _build_story_modal() -> void:
    story_modal = _create_info_dialog(
        "⚔️ CAMPAGNA STORIA: LA VIA DEI QUATTRO CLUB",
        "🏆 ATTO I: LA TAVERNA DEI QUATTRO ASSI\n\n" +
        "Benvenuto sfidante! La modalità Campagna ti porterà a scalare i Club di Burraco più prestigiosi del reame.\n\n" +
        "• Sfida i Campioni dei Club per sbloccare carte leggendarie animate.\n" +
        "• Apri le Blind Box esclusive ad ogni vittoria per completare il tuo mazzo.\n" +
        "• Modificatori speciali di smazzata e abilità passive delle creature!\n\n" +
        "Preparati: l'Atto I sarà sbloccato nella Stagione 1!"
    )

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

    var p = Panel.new()
    p.custom_minimum_size = Vector2(620, 360)
    p.size = Vector2(620, 360)
    p.position = Vector2((1280 - 620) / 2.0, (720 - 360) / 2.0)
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.11, 0.15, 0.98)
    sb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(10)
    p.add_theme_stylebox_override("panel", sb)
    modal.add_child(p)

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
    ok_btn.custom_minimum_size = Vector2(140, 38)
    ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var osb = StyleBoxFlat.new()
    osb.bg_color = Color(0.15, 0.2, 0.28, 0.95)
    osb.border_color = Color(0.96, 0.82, 0.25, 1.0)
    osb.set_border_width_all(2)
    osb.set_corner_radius_all(6)
    ok_btn.add_theme_stylebox_override("normal", osb)
    ok_btn.pressed.connect(func(): modal.visible = false)
    vbox.add_child(ok_btn)

    return modal

# ==============================================================================
# TAB SWITCHING
# ==============================================================================
func switch_tab(idx: int) -> void:
    table_layer.visible = (idx == 0)
    blind_box_layer.visible = (idx == 1)
    club_layer.visible = (idx == 2)

func _check_cli_args() -> void:
    var all_args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
    for arg in all_args:
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

                    mgr.refresh_all_ui()
            )

        if "screenshot" in arg:
            get_tree().create_timer(1.2).timeout.connect(func():
                var img = get_viewport().get_texture().get_image()
                var p = ProjectSettings.globalize_path("res://assets/game_screenshot.png")
                img.save_png(p)
                print("SCREENSHOT_SAVED: ", p)
                get_tree().quit()
            )
