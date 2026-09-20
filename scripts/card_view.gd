class_name CardView
extends Control

const BurracoCardData = preload("res://scripts/card_data.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

signal card_clicked(card_view: CardView)
signal card_hovered(card_view: CardView, is_hovered: bool)

@export var card_data: BurracoCardData
@export var is_selected: bool = false
@export var is_face_up: bool = true
@export var is_compact: bool = false

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
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        card_clicked.emit(self)

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
        var back_tex = AssetLoader.get_tex("res://assets/card_back_luxury.png")
        if back_tex:
            draw_texture_rect(back_tex, rect, false)
        return

    # 3. Disegno Carta: se esiste la carta artistica completa (es. Picche AAA), usala direttamente!
    var dedicated_tex = _get_dedicated_card_texture()
    if dedicated_tex != null:
        draw_texture_rect(dedicated_tex, rect, false)
        return

    # 4. Fallback: Base Carta composita
    var front_tex = AssetLoader.get_tex("res://assets/card_front_base.png")
    if front_tex:
        draw_texture_rect(front_tex, rect, false)
    else:
        draw_rect(rect, Color(0.98, 0.98, 0.96), true)

    if card_data == null: return

    # 4. Angoli: Valore Numerico e Mini Seme
    var suit_col = card_data.get_suit_color()
    var font = ThemeDB.fallback_font
    var rank_str = card_data.get_rank_string()
    var suit_tex = _get_suit_texture(card_data.suit)

    if is_compact:
        # Mini versione per calate sul tavolo
        draw_string(font, draw_pos + Vector2(6, 17), rank_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, suit_col)
        if suit_tex:
            draw_texture_rect(suit_tex, Rect2(draw_pos + Vector2(5, 19), Vector2(12, 12)), false)

        draw_string(font, draw_pos + Vector2(size.x - 22, size.y - 7), rank_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, suit_col)
        if suit_tex:
            draw_texture_rect(suit_tex, Rect2(draw_pos + Vector2(size.x - 18, size.y - 27), Vector2(11, 11)), false)

        # Illustrazione Creatura / Seme centrale
        var creature_tex = _get_creature_texture()
        if creature_tex != null:
            var c_rect = Rect2(draw_pos + Vector2(10, 24), Vector2(size.x - 20, size.x - 20))
            draw_texture_rect(creature_tex, c_rect, false)
        elif suit_tex != null:
            var s_rect = Rect2(draw_pos + Vector2(size.x/2.0 - 15, size.y/2.0 - 15), Vector2(30, 30))
            draw_texture_rect(suit_tex, s_rect, false)
    else:
        # Full size per la mano
        # Top-Left
        draw_string(font, draw_pos + Vector2(10, 24), rank_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, suit_col)
        if suit_tex:
            draw_texture_rect(suit_tex, Rect2(draw_pos + Vector2(8, 27), Vector2(18, 18)), false)

        # Bottom-Right
        draw_string(font, draw_pos + Vector2(size.x - 32, size.y - 12), rank_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, 21, suit_col)
        if suit_tex:
            draw_texture_rect(suit_tex, Rect2(draw_pos + Vector2(size.x - 28, size.y - 42), Vector2(16, 16)), false)

        # Illustrazione Creatura al Centro (o Grande Gemma Seme)
        var creature_tex = _get_creature_texture()
        if creature_tex != null:
            var c_rect = Rect2(draw_pos + Vector2(12, 34), Vector2(size.x - 24, size.x - 24))
            draw_texture_rect(creature_tex, c_rect, false)
        elif suit_tex != null:
            var s_rect = Rect2(draw_pos + Vector2(size.x/2.0 - 24, size.y/2.0 - 24), Vector2(48, 48))
            draw_texture_rect(suit_tex, s_rect, false)

        # Targhetta Nome Creatura (solo full size)
        var badge_rect = Rect2(draw_pos + Vector2(8, size.y - 22), Vector2(size.x - 16, 16))
        draw_rect(badge_rect, Color(0.08, 0.10, 0.15, 0.90), true)
        var is_rare_or_wild = card_data.is_wildcard() or card_data.creature_rarity == "Legendary" or card_data.creature_rarity == "Epic"
        var badge_border = Color(0.95, 0.78, 0.22) if is_rare_or_wild else Color(0.65, 0.7, 0.78)
        draw_rect(badge_rect, badge_border, false, 1.5)
        var text_col = Color(1.0, 0.85, 0.3) if is_rare_or_wild else Color(0.92, 0.92, 0.92)
        draw_string(font, draw_pos + Vector2(10, size.y - 10), card_data.creature_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 10, text_col)

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

