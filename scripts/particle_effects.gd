class_name ParticleEffects
extends Node

static func burst_burraco(parent: Node, pos: Vector2, b_type: int) -> void:
    if parent == null:
        return
    var parts = CPUParticles2D.new()
    parent.add_child(parts)
    parts.global_position = pos
    parts.emitting = false
    parts.one_shot = true
    parts.explosiveness = 0.95
    parts.amount = 48
    parts.lifetime = 1.1
    parts.direction = Vector2(0, -1)
    parts.spread = 180.0
    parts.initial_velocity_min = 90.0
    parts.initial_velocity_max = 240.0
    parts.gravity = Vector2(0, 140.0)
    parts.scale_amount_min = 3.5
    parts.scale_amount_max = 7.0

    var grad = Gradient.new()
    if b_type == 3:
        grad.colors = PackedColorArray([Color(1.0, 0.95, 0.5, 1.0), Color(1.0, 0.78, 0.15, 0.9), Color(1.0, 0.5, 0.0, 0.0)])
    elif b_type == 2:
        grad.colors = PackedColorArray([Color(1.0, 0.9, 0.3, 1.0), Color(1.0, 0.38, 0.1, 0.95), Color(0.8, 0.1, 0.0, 0.0)])
    else:
        grad.colors = PackedColorArray([Color(0.85, 0.95, 1.0, 1.0), Color(0.3, 0.7, 1.0, 0.9), Color(0.1, 0.2, 0.7, 0.0)])
    grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    parts.color_ramp = grad

    parts.emitting = true
    _auto_destroy(parent, parts, 1.4)

static func burst_box_reveal(parent: Node, pos: Vector2) -> void:
    if parent == null:
        return
    var parts = CPUParticles2D.new()
    parent.add_child(parts)
    parts.global_position = pos
    parts.emitting = false
    parts.one_shot = true
    parts.explosiveness = 0.92
    parts.amount = 70
    parts.lifetime = 1.4
    parts.spread = 180.0
    parts.initial_velocity_min = 120.0
    parts.initial_velocity_max = 320.0
    parts.gravity = Vector2(0, 110.0)
    parts.scale_amount_min = 4.0
    parts.scale_amount_max = 9.0

    var grad = Gradient.new()
    grad.colors = PackedColorArray([
        Color(1.0, 1.0, 0.8, 1.0),
        Color(1.0, 0.8, 0.2, 0.95),
        Color(0.3, 0.9, 1.0, 0.8),
        Color(0.9, 0.2, 0.8, 0.0)
    ])
    grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
    parts.color_ramp = grad

    parts.emitting = true
    _auto_destroy(parent, parts, 1.6)

static func _auto_destroy(parent: Node, target: Node, delay: float) -> void:
    var tree = parent.get_tree()
    if tree:
        tree.create_timer(delay).timeout.connect(target.queue_free)
