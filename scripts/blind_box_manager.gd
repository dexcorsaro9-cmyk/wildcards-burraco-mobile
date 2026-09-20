class_name BlindBoxManager
extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")

signal creature_unlocked(creature_data: Dictionary)

@export var is_opening: bool = false
var box_scale: float = 1.0
var box_shake: float = 0.0
var glow_pulse: float = 0.0

@onready var open_std_btn: Button = get_node_or_null("BoxButtons/OpenStd")
@onready var open_vip_btn: Button = get_node_or_null("BoxButtons/OpenVip")

var reveal_overlay: PanelContainer = null
var current_revealed: Dictionary = {}

var creatures_db = [
    {"name": "Neon Chimera", "rank_str": "JK", "rarity": "Legendary", "material": "24K Gold and Cyber Hologram", "lore": "Entità cosmica suprema, signora di tutti e quattro gli elementi.", "tex": "res://assets/cards/joker.png"},
    {"name": "Cyber Pinella", "rank_str": "2", "rarity": "Legendary", "material": "Translucent Neon Amber", "lore": "Cucciolo di drago solare, trasforma i due in pura magia tattile.", "tex": "res://assets/cards/diamonds_2.png"},
    {"name": "Apex Dragon King", "rank_str": "K", "rarity": "Epic", "material": "Polished Royal Chrome", "lore": "Sovrano guerriero di cuori, domina il campo con il Sacro Rubino.", "tex": "res://assets/cards/hearts_13.png"},
    {"name": "Mystic Empress", "rank_str": "Q", "rarity": "Epic", "material": "Living Emerald Silk", "lore": "Incantatrice dei boschi di fiori, scruta il mazzo con occhi divini.", "tex": "res://assets/cards/clubs_12.png"},
    {"name": "Solar Sphinx Ace", "rank_str": "A", "rarity": "Epic", "material": "Solar Topaz Crystal", "lore": "Lancia celeste dei semi dorati, conferisce il massimo prestigio.", "tex": "res://assets/cards/diamonds_1.png"},
    {"name": "Rogue Golem Jack", "rank_str": "J", "rarity": "Rare", "material": "Arcane Blue Sapphire Steel", "lore": "Cavaliere impavido di picche, sottrae fiches e protegge le calate.", "tex": "res://assets/cards/spades_11.png"}
]

func _ready() -> void:
    if open_std_btn:
        open_std_btn.pressed.connect(func(): trigger_box_open(false))
    if open_vip_btn:
        open_vip_btn.pressed.connect(func(): trigger_box_open(true))

func _process(delta: float) -> void:
    glow_pulse += delta * 2.5
    if box_shake > 0.0:
        box_shake = move_toward(box_shake, 0.0, delta * 2.8)
        queue_redraw()
    else:
        queue_redraw()

func trigger_box_open(is_vip: bool) -> void:
    if is_opening: return
    var cost = 300 if is_vip else 100

    var coins_lbl = get_node_or_null("/root/Main/UI/HeaderBar/Stats/CoinsLabel")
    var current_coins = 750
    if coins_lbl:
        var txt = coins_lbl.text.replace(" GETTONI", "").replace(",", "").strip_edges()
        if txt.is_valid_int():
            current_coins = txt.to_int()

    if current_coins < cost:
        var status = get_node_or_null("/root/Main/UI/TableLayer/StatusLabel")
        if status: status.text = "Gettoni insufficienti per aprire questo forziere!"
        return

    current_coins -= cost
    if coins_lbl:
        coins_lbl.text = "%d GETTONI" % current_coins

    is_opening = true
    box_shake = 1.0

    var audio = get_node_or_null("/root/AudioSynth")
    if audio and audio.has_method("play_chip_clink"):
        audio.play_chip_clink()

    var tween = create_tween()
    tween.tween_property(self, "box_scale", 1.25, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func():
        if audio and audio.has_method("play_box_open"):
            audio.play_box_open()
        var center = size / 2.0
        var ParticleFx = preload("res://scripts/particle_effects.gd")
        ParticleFx.burst_box_reveal(self, center)

        var rolled = creatures_db.pick_random()
        if is_vip:
            rolled = creatures_db[0] if randf() < 0.45 else creatures_db[1]
        _show_reveal_modal(rolled)
        box_scale = 1.0
        is_opening = false
    )

func _show_reveal_modal(item: Dictionary) -> void:
    if reveal_overlay != null:
        reveal_overlay.queue_free()

    reveal_overlay = PanelContainer.new()
    add_child(reveal_overlay)
    reveal_overlay.custom_minimum_size = Vector2(440, 480)
    reveal_overlay.position = (size - Vector2(440, 480)) / 2.0

    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.12, 0.96)
    sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
    sb.border_width_left = 3
    sb.border_width_top = 3
    sb.border_width_right = 3
    sb.border_width_bottom = 3
    sb.corner_radius_top_left = 16
    sb.corner_radius_top_right = 16
    sb.corner_radius_bottom_left = 16
    sb.corner_radius_bottom_right = 16
    sb.shadow_size = 24
    sb.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
    reveal_overlay.add_theme_stylebox_override("panel", sb)

    var vbox = VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 10)
    reveal_overlay.add_child(vbox)

    var title = Label.new()
    title.text = "✨ NUOVA CARTA SBLOCCATA! ✨"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    title.add_theme_font_size_override("font_size", 18)
    vbox.add_child(title)

    var name_lbl = Label.new()
    name_lbl.text = item.name.to_upper()
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
    name_lbl.add_theme_font_size_override("font_size", 22)
    vbox.add_child(name_lbl)

    var tex_rect = TextureRect.new()
    tex_rect.custom_minimum_size = Vector2(140, 198)
    tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var c_tex = AssetLoader.get_tex(item.tex)
    if c_tex: tex_rect.texture = c_tex
    var center_c = CenterContainer.new()
    center_c.add_child(tex_rect)
    vbox.add_child(center_c)

    var rar_lbl = Label.new()
    rar_lbl.text = "Rarità: %s | Finitura: %s" % [item.rarity, item.material]
    rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rar_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0) if item.rarity == "Legendary" else Color(1.0, 0.8, 0.3))
    rar_lbl.add_theme_font_size_override("font_size", 12)
    vbox.add_child(rar_lbl)

    var lore_lbl = Label.new()
    lore_lbl.text = item.lore
    lore_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lore_lbl.custom_minimum_size = Vector2(380, 40)
    lore_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
    lore_lbl.add_theme_font_size_override("font_size", 11)
    vbox.add_child(lore_lbl)

    var collect_btn = Button.new()
    collect_btn.text = "RACCOGLI NELL'ALBUM"
    collect_btn.custom_minimum_size = Vector2(220, 38)
    collect_btn.pressed.connect(func():
        reveal_overlay.queue_free()
        reveal_overlay = null
    )
    var btn_c = CenterContainer.new()
    btn_c.add_child(collect_btn)
    vbox.add_child(btn_c)

func _draw() -> void:
    var center = size / 2.0 - Vector2(0, 40.0)
    var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * box_shake * 16.0
    var b_pos = center + shake_offset

    var base_size = 230.0 * box_scale
    var b_rect = Rect2(b_pos - Vector2(base_size / 2.0, base_size / 2.0), Vector2(base_size, base_size))

    var glow_rad = base_size * 0.7 + sin(glow_pulse) * 12.0
    draw_circle(b_pos, glow_rad, Color(1.0, 0.78, 0.2, 0.15 + box_shake * 0.25))

    var box_tex = AssetLoader.get_tex("res://assets/mystery_box_luxury.png")
    if box_tex:
        draw_texture_rect(box_tex, b_rect, false)
    else:
        draw_rect(b_rect, Color(0.35, 0.15, 0.65), true)
