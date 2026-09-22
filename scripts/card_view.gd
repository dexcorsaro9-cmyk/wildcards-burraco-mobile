class_name CardView
extends Control

const BurracoCardData = preload("res://scripts/card_data.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

signal card_clicked(card_view: CardView)
signal card_hovered(card_view: CardView, is_hovered: bool)
signal card_long_pressed(card_view: CardView)

@export var card_data: BurracoCardData
@export var is_selected: bool = false
@export var is_face_up: bool = true
@export var is_compact: bool = false
@export var use_generic_long_press_preview: bool = true

# Dimensioni carta (standard casinò e compatta per calate sul tavolo)
const CARD_WIDTH: float = 104.0
const CARD_HEIGHT: float = 152.0
const COMPACT_WIDTH: float = 68.0
const COMPACT_HEIGHT: float = 98.0

# Parametri Balatro Spring Physics
var visual_offset_y: float = 0.0
var vel_y: float = 0.0
const POS_TENSION: float = 420.0
const POS_DAMPING: float = 24.0

var target_rot: float = 0.0
var rot_velocity: float = 0.0
const ROT_TENSION: float = 460.0
const ROT_DAMPING: float = 22.0

var target_scale_val: float = 1.0
var scale_velocity: float = 0.0
const SCALE_TENSION: float = 500.0
const SCALE_DAMPING: float = 26.0

var is_hovered: bool = false
var audio_synth: Node = null

# Leggibilità: crop centrato sull'arte dedicata invece dello stretch
const ART_ZOOM: float = 1.85
const ART_FOCUS_Y: float = 0.36

# Tocca-e-tieni-premuto: rivela l'illustrazione intera a piena tela
const LONG_PRESS_TIME: float = 0.42
const LONG_PRESS_MOVE_TOLERANCE: float = 14.0
var _press_timer: Timer = null
var _press_start_pos: Vector2 = Vector2.ZERO
var _long_press_fired: bool = false

func _ready() -> void:
    var w = COMPACT_WIDTH if is_compact else CARD_WIDTH
    var h = COMPACT_HEIGHT if is_compact else CARD_HEIGHT
    custom_minimum_size = Vector2(w, h)
    size = Vector2(w, h)
    pivot_offset = size / 2.0
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)
    audio_synth = get_tree().root.find_child("AudioSynth", true, false)

    _press_timer = Timer.new()
    _press_timer.one_shot = true
    add_child(_press_timer)
    _press_timer.timeout.connect(_on_long_press_timeout)

func setup(p_card: BurracoCardData, p_compact: bool = false) -> void:
    card_data = p_card
    is_compact = p_compact
    var w = COMPACT_WIDTH if is_compact else CARD_WIDTH
    var h = COMPACT_HEIGHT if is_compact else CARD_HEIGHT
    custom_minimum_size = Vector2(w, h)
    size = Vector2(w, h)
    pivot_offset = size / 2.0
    queue_redraw()

func _process(delta: float) -> void:
    var target_y = 0.0
    if not is_compact:
        target_y = -34.0 if is_selected else (-22.0 if is_hovered else 0.0)
    else:
        target_y = -8.0 if is_hovered else 0.0

    var disp_y = target_y - visual_offset_y
    var force_y = disp_y * POS_TENSION - vel_y * POS_DAMPING
    vel_y += force_y * delta
    visual_offset_y += vel_y * delta

    if is_hovered:
        var mouse_local = get_local_mouse_position() - pivot_offset
        target_rot = clamp(mouse_local.x * 0.016, -0.22, 0.22)
    else:
        target_rot = 0.0

    var disp_rot = target_rot - rotation
    var force_rot = disp_rot * ROT_TENSION - rot_velocity * ROT_DAMPING
    rot_velocity += force_rot * delta
    rotation += rot_velocity * delta

    if not is_compact:
        target_scale_val = 1.15 if (is_hovered or is_selected) else 1.0
    else:
        target_scale_val = 1.08 if is_hovered else 1.0

    var current_scale_val = scale.x
    var disp_scale = target_scale_val - current_scale_val
    var force_scale = disp_scale * SCALE_TENSION - scale_velocity * SCALE_DAMPING
    scale_velocity += force_scale * delta
    var new_s = current_scale_val + scale_velocity * delta
    scale = Vector2(new_s, new_s)

    queue_redraw()

func _on_mouse_entered() -> void:
    is_hovered = true
    z_index = 30
    card_hovered.emit(self, true)

func _on_mouse_exited() -> void:
    is_hovered = false
    z_index = 15 if is_selected else 0
    card_hovered.emit(self, false)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _press_start_pos = event.position
            _long_press_fired = false
            if _press_timer:
                _press_timer.start(LONG_PRESS_TIME)
        else:
            if _press_timer:
                _press_timer.stop()
            if not _long_press_fired:
                card_clicked.emit(self)
    elif event is InputEventMouseMotion and _press_timer and not _press_timer.is_stopped():
        if event.position.distance_to(_press_start_pos) > LONG_PRESS_MOVE_TOLERANCE:
            _press_timer.stop()

func _on_long_press_timeout() -> void:
    _long_press_fired = true
    card_long_pressed.emit(self)
    if use_generic_long_press_preview:
        _show_art_preview()

func set_selected(p_sel: bool) -> void:
    is_selected = p_sel
    z_index = 15 if is_selected else 0
    queue_redraw()

func _draw() -> void:
    var draw_pos = Vector2(0, visual_offset_y)
    var rect = Rect2(draw_pos, size)

    # 1. Ombra proiettata morbida
    var shadow_rect = Rect2(draw_pos + Vector2(0, 8 if (is_hovered or is_selected) else 4), rect.size)
    draw_rect(shadow_rect, Color(0, 0, 0, 0.35 if (is_hovered or is_selected) else 0.18), true)

    # 2. Glow di selezione dorato vibrante
    if is_selected:
        var glow_rect = rect.grow(5.0)
        draw_rect(glow_rect, Color(1.0, 0.82, 0.25, 0.7), false, 4.0)

    if not is_face_up:
        var back_tex = AssetLoader.get_tex("res://assets/card_back_taverna.png")
        if back_tex == null:
            back_tex = AssetLoader.get_tex("res://assets/card_back_luxury.png")
        if back_tex:
            draw_texture_rect(back_tex, rect, false)
        return

    if card_data == null: return

    # 3. Arte di base: crop centrato sull'illustrazione dedicata (mai stirata)
    var dedicated_tex = _get_dedicated_card_texture()
    if dedicated_tex != null:
        _draw_cropped_art(dedicated_tex, rect)
    else:
        var front_tex = AssetLoader.get_tex("res://assets/card_front_base.png")
        if front_tex:
            draw_texture_rect(front_tex, rect, false)
        else:
            draw_rect(rect, Color(0.98, 0.98, 0.96), true)
        var creature_tex = _get_creature_texture()
        if creature_tex != null:
            var inset = Vector2(size.x * 0.14, size.y * 0.18)
            var c_rect = Rect2(draw_pos + inset, size - inset * 2.0)
            draw_texture_rect(creature_tex, c_rect, false)

    # 4. Overlay di leggibilità: scrim + indice grande a doppio angolo + targhetta nome
    _draw_legibility_overlay(draw_pos)

func _draw_cropped_art(tex: Texture2D, rect: Rect2) -> void:
    var tex_size = tex.get_size()
    if tex_size.x <= 0.0 or tex_size.y <= 0.0:
        draw_texture_rect(tex, rect, false)
        return
    var target_aspect = rect.size.x / rect.size.y
    var crop_h = tex_size.y / ART_ZOOM
    var crop_w = crop_h * target_aspect
    if crop_w > tex_size.x:
        crop_w = tex_size.x
        crop_h = crop_w / target_aspect
    var src_x = (tex_size.x - crop_w) * 0.5
    var src_y = clamp(tex_size.y * ART_FOCUS_Y - crop_h * 0.5, 0.0, max(0.0, tex_size.y - crop_h))
    var src_rect = Rect2(src_x, src_y, crop_w, crop_h)
    draw_texture_rect_region(tex, rect, src_rect)

func _draw_legibility_overlay(draw_pos: Vector2) -> void:
    var is_red = card_data.suit == BurracoCardData.Suit.HEARTS or card_data.suit == BurracoCardData.Suit.DIAMONDS
    var chip_col = Color(0.89, 0.70, 0.30) if card_data.is_joker else (Color(0.878, 0.204, 0.180) if is_red else Color(0.125, 0.137, 0.164))
    var needs_border = not card_data.is_joker and not is_red
    var rank_col = Color(0.11, 0.08, 0.03) if card_data.is_joker else Color(0.98, 0.965, 0.914)
    var rank_str = card_data.get_rank_string()
    var suit_tex = AssetLoader.get_tex("res://assets/suit_joker.png") if card_data.is_joker else _get_suit_texture(card_data.suit)
    var font = ThemeDB.fallback_font

    # Bande scrim in alto/basso per garantire contrasto sopra l'illustrazione
    var top_band_h = size.y * (0.30 if is_compact else 0.34)
    var bot_band_h = size.y * (0.24 if is_compact else 0.26)
    _draw_v_scrim(draw_pos, Vector2(size.x, top_band_h), true)
    _draw_v_scrim(draw_pos + Vector2(0, size.y - bot_band_h), Vector2(size.x, bot_band_h), false)

    # Indice principale (alto-sinistra, grande)
    var rank_size: int = 13 if is_compact else 19
    var icon_size: float = 11.0 if is_compact else 15.0
    var pad: float = 4.0 if is_compact else 6.0
    _draw_index_chip(draw_pos + Vector2(pad, pad), chip_col, needs_border, rank_col, rank_str, rank_size, suit_tex, icon_size, font)

    # Indice speculare (basso-destra, più piccolo) come su una carta vera
    var s_rank: int = int(round(rank_size * 0.68))
    var s_icon: float = icon_size * 0.7
    var s_pad: float = pad * 0.75
    var s_chip_size = _measure_chip(rank_str, s_rank, s_icon, s_pad)
    _draw_index_chip(draw_pos + Vector2(size.x - s_pad - s_chip_size.x, size.y - s_pad - s_chip_size.y), chip_col, needs_border, rank_col, rank_str, s_rank, suit_tex, s_icon, font)

    # Targhetta nome creatura (solo full-size, per non affollare le carte compatte)
    if not is_compact and card_data.creature_name != "":
        var is_rare_or_wild = card_data.is_wildcard() or card_data.creature_rarity == "Legendary" or card_data.creature_rarity == "Epic"
        var text_col = Color(1.0, 0.85, 0.35) if is_rare_or_wild else Color(0.90, 0.90, 0.90)
        draw_string(font, draw_pos + Vector2(8, size.y - 8), card_data.creature_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 9, text_col)

func _measure_chip(rank_str: String, rank_size: int, icon_size: float, pad: float) -> Vector2:
    var font = ThemeDB.fallback_font
    var text_w = font.get_string_size(rank_str, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x
    var chip_w = max(max(text_w, icon_size), rank_size * 0.9) + pad * 1.8
    var chip_h = rank_size + icon_size + pad * 1.7
    return Vector2(chip_w, chip_h)

func _draw_v_scrim(pos: Vector2, band_size: Vector2, top: bool) -> void:
    if band_size.x <= 0.0 or band_size.y <= 0.0: return
    var c_edge = Color(0.02, 0.02, 0.03, 0.0)
    var c_solid = Color(0.02, 0.02, 0.03, 0.55)
    var pts := PackedVector2Array([pos, pos + Vector2(band_size.x, 0), pos + band_size, pos + Vector2(0, band_size.y)])
    var cols: PackedColorArray
    if top:
        cols = PackedColorArray([c_solid, c_solid, c_edge, c_edge])
    else:
        cols = PackedColorArray([c_edge, c_edge, c_solid, c_solid])
    draw_polygon(pts, cols)

func _draw_index_chip(pos: Vector2, bg_col: Color, border: bool, rank_col: Color, rank_str: String, rank_size: int, suit_tex: Texture2D, icon_size: float, font: Font) -> void:
    var pad = icon_size * 0.42
    var chip_size = _measure_chip(rank_str, rank_size, icon_size, pad)
    var chip_rect = Rect2(pos, chip_size)
    draw_rect(chip_rect, Color(0, 0, 0, 0.30), true)
    draw_rect(chip_rect.grow(-1.0), bg_col, true)
    if border:
        draw_rect(chip_rect, Color(0.42, 0.46, 0.53, 0.9), false, 1.2)

    var text_size = font.get_string_size(rank_str, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size)
    var tx = pos.x + (chip_size.x - text_size.x) * 0.5
    var ty = pos.y + pad * 0.9 + rank_size
    draw_string(font, Vector2(tx, ty), rank_str, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, rank_col)

    if suit_tex:
        var icon_x = pos.x + (chip_size.x - icon_size) * 0.5
        var icon_y = ty + pad * 0.55
        draw_texture_rect(suit_tex, Rect2(Vector2(icon_x, icon_y), Vector2(icon_size, icon_size)), false)

func _show_art_preview() -> void:
    if card_data == null: return
    var art_tex = _get_dedicated_card_texture()
    if art_tex == null: return

    Input.vibrate_handheld(15)
    var audio = get_tree().root.find_child("AudioSynth", true, false)
    if audio and audio.has_method("play_chat_pop"):
        audio.play_chat_pop()

    var overlay = Control.new()
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.top_level = true
    overlay.z_index = 200

    var scrim = ColorRect.new()
    scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
    scrim.color = Color(0, 0, 0, 0.0)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(scrim)

    var tex_size = art_tex.get_size()
    var art_h = 460.0
    var art_w = art_h * (tex_size.x / tex_size.y) if tex_size.y > 0.0 else art_h * 0.79

    var art = TextureRect.new()
    art.texture = art_tex
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.custom_minimum_size = Vector2(art_w, art_h)
    art.size = Vector2(art_w, art_h)
    art.set_anchors_preset(Control.PRESET_CENTER)
    art.position = art.position - art.size / 2.0
    art.pivot_offset = art.size / 2.0
    art.scale = Vector2(0.85, 0.85)
    art.modulate.a = 0.0
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(art)

    get_tree().root.add_child(overlay)

    var tw = overlay.create_tween()
    tw.set_parallel(true)
    tw.tween_property(scrim, "color:a", 0.80, 0.16)
    tw.tween_property(art, "modulate:a", 1.0, 0.16)
    tw.tween_property(art, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    overlay.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed:
            var tw2 = overlay.create_tween()
            tw2.set_parallel(true)
            tw2.tween_property(scrim, "color:a", 0.0, 0.14)
            tw2.tween_property(art, "modulate:a", 0.0, 0.14)
            tw2.tween_callback(overlay.queue_free)
    )

func _get_suit_texture(s: BurracoCardData.Suit) -> Texture2D:
    match s:
        BurracoCardData.Suit.HEARTS: return AssetLoader.get_tex("res://assets/suit_hearts.png")
        BurracoCardData.Suit.DIAMONDS: return AssetLoader.get_tex("res://assets/suit_diamonds.png")
        BurracoCardData.Suit.CLUBS: return AssetLoader.get_tex("res://assets/suit_clubs.png")
        BurracoCardData.Suit.SPADES: return AssetLoader.get_tex("res://assets/suit_spades.png")
        _: return AssetLoader.get_tex("res://assets/suit_joker.png")

func _get_creature_texture() -> Texture2D:
    if card_data == null: return null
    if card_data.is_joker: return AssetLoader.get_tex("res://assets/creature_neon_chimera.png")
    if card_data.is_pinella(): return AssetLoader.get_tex("res://assets/creature_cyber_pinella.png")
    if card_data.rank == BurracoCardData.Rank.KING: return AssetLoader.get_tex("res://assets/creature_apex_dragon.png")
    if card_data.rank == BurracoCardData.Rank.ACE: return AssetLoader.get_tex("res://assets/creature_solar_sphinx.png")
    return null

func _get_dedicated_card_texture() -> Texture2D:
    if card_data == null: return null
    if card_data.is_joker:
        return AssetLoader.get_tex("res://assets/cards/joker.png")
    var suit_name = ""
    match card_data.suit:
        BurracoCardData.Suit.SPADES: suit_name = "spades"
        BurracoCardData.Suit.HEARTS: suit_name = "hearts"
        BurracoCardData.Suit.DIAMONDS: suit_name = "diamonds"
        BurracoCardData.Suit.CLUBS: suit_name = "clubs"
    if suit_name != "":
        var p = "res://assets/cards/%s_%d.png" % [suit_name, card_data.rank]
        return AssetLoader.get_tex(p)
    return null
