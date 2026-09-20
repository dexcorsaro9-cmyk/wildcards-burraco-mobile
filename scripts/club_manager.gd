class_name CardClubManager
extends Control

@export var club_prestige: int = 50
@export var club_coins: int = 750

var unlocked_furniture = {
    "table_vip": true,
    "chesterfield": false,
    "trophy_gold": false,
    "jukebox": false
}

func _draw() -> void:
    # Disegna Stanza Isometrica Procedurale
    var center = Vector2(size.x / 2.0, size.y / 2.0 + 30.0)
    var tile_w = 70.0
    var tile_h = 35.0

    # 1. Pavimento Parquet a Losanghe Isometriche (8x8)
    for x in range(-4, 5):
        for y in range(-4, 5):
            var iso_x = center.x + (x - y) * tile_w * 0.5
            var iso_y = center.y + (x + y) * tile_h * 0.5
            var poly = PackedVector2Array([
                Vector2(iso_x, iso_y - tile_h * 0.5),
                Vector2(iso_x + tile_w * 0.5, iso_y),
                Vector2(iso_x, iso_y + tile_h * 0.5),
                Vector2(iso_x - tile_w * 0.5, iso_y)
            ])
            var col = Color(0.18, 0.12, 0.08) if (x + y) % 2 == 0 else Color(0.24, 0.16, 0.10)
            draw_colored_polygon(poly, col)
            draw_polyline(poly, Color(0.12, 0.08, 0.05), 1.0)

    # 2. Tavolo VIP Smeraldo Centrale
    if unlocked_furniture.table_vip:
        var t_center = center + Vector2(0, -10)
        draw_circle(t_center, 40, Color(0.08, 0.35, 0.18)) # Feltro Smeraldo
        draw_circle(t_center, 42, Color(0.85, 0.65, 0.15)) # Bordo Ottone

    # 3. Trofeo d'Oro Burraco (se sbloccato)
    if unlocked_furniture.trophy_gold:
        var tr_pos = center + Vector2(110, -50)
        draw_rect(Rect2(tr_pos + Vector2(-12, 0), Vector2(24, 30)), Color(0.2, 0.2, 0.2))
        draw_circle(tr_pos + Vector2(0, -10), 14, Color(1.0, 0.85, 0.2))

func buy_furniture(item_key: String, cost: int, prestige_gain: int) -> bool:
    if club_coins >= cost and not unlocked_furniture[item_key]:
        club_coins -= cost
        club_prestige += prestige_gain
        unlocked_furniture[item_key] = true
        queue_redraw()
        return true
    return false
