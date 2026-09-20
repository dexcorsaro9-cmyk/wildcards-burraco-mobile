class_name AudioSynth
extends Node

var sfx_player: AudioStreamPlayer
var sfx_generator: AudioStreamGenerator
var sfx_playback: AudioStreamGeneratorPlayback

var bgm_player: AudioStreamPlayer
var bgm_generator: AudioStreamGenerator
var bgm_playback: AudioStreamGeneratorPlayback

var sample_rate: float = 22050.0
var is_muted: bool = true
var bgm_time: float = 0.0
var current_note_idx: int = 0
var note_timer: float = 0.0

# Melodia Taverna Lofi / Liuto Medievale (Am -> F -> C -> G)
var melody_notes = [
    220.0, 261.63, 329.63, 440.0, 329.63, 261.63, # A minor arpeggio
    174.61, 220.0, 261.63, 349.23, 261.63, 220.0, # F major arpeggio
    130.81, 164.81, 196.0, 261.63, 196.0, 164.81, # C major arpeggio
    196.0, 246.94, 293.66, 392.0, 293.66, 246.94  # G major arpeggio
]
var note_duration: float = 0.38

func _ready() -> void:
    # 1. SFX Setup
    sfx_player = AudioStreamPlayer.new()
    add_child(sfx_player)
    sfx_generator = AudioStreamGenerator.new()
    sfx_generator.mix_rate = sample_rate
    sfx_generator.buffer_length = 0.3
    sfx_player.stream = sfx_generator
    sfx_player.volume_db = -2.0
    sfx_player.play()
    sfx_playback = sfx_player.get_stream_playback()

    # 2. BGM Setup
    bgm_player = AudioStreamPlayer.new()
    add_child(bgm_player)
    bgm_generator = AudioStreamGenerator.new()
    bgm_generator.mix_rate = sample_rate
    bgm_generator.buffer_length = 0.4
    bgm_player.stream = bgm_generator
    bgm_player.volume_db = -16.0 # Dolce sottofondo per non sovrastare
    bgm_player.play()
    bgm_playback = bgm_player.get_stream_playback()

func _process(delta: float) -> void:
    if is_muted or bgm_playback == null: return
    _fill_bgm_buffer()

func _fill_bgm_buffer() -> void:
    var frames_needed = bgm_playback.get_frames_available()
    if frames_needed <= 0: return

    for i in range(frames_needed):
        note_timer += 1.0 / sample_rate
        if note_timer >= note_duration:
            note_timer = 0.0
            current_note_idx = (current_note_idx + 1) % melody_notes.size()

        var freq = melody_notes[current_note_idx]
        var note_progress = note_timer / note_duration
        # Inviluppo pizzicato tipo liuto/arpa
        var env = exp(-note_progress * 5.0) * 0.16
        bgm_time += 1.0 / sample_rate
        # Suono caldo con armonica morbida
        var sample = (sin(bgm_time * freq * 2.0 * PI) * 0.7 + sin(bgm_time * freq * 4.0 * PI) * 0.3) * env
        bgm_playback.push_frame(Vector2(sample, sample))

func toggle_mute() -> bool:
    is_muted = not is_muted
    if is_muted:
        sfx_player.volume_db = -80.0
        bgm_player.volume_db = -80.0
    else:
        sfx_player.volume_db = -2.0
        bgm_player.volume_db = -16.0
    return is_muted

func play_card_slide() -> void:
    if is_muted: return
    _synthesize_sfx(0.08, 380.0, 180.0, 0.25, true)

func play_card_place() -> void:
    if is_muted: return
    _synthesize_sfx(0.07, 190.0, 60.0, 0.45, false)

func play_chip_clink() -> void:
    if is_muted: return
    _synthesize_sfx(0.14, 1650.0, 850.0, 0.35, false)

func play_burraco_fanfare() -> void:
    if is_muted: return
    _synthesize_sfx_arpeggio([261.63, 329.63, 392.0, 523.25, 659.25], 0.45)

func play_win_fanfare() -> void:
    if is_muted: return
    _synthesize_sfx_arpeggio([392.0, 523.25, 659.25, 783.99, 1046.5], 0.65)

func play_defeat() -> void:
    if is_muted: return
    _synthesize_sfx_arpeggio([329.63, 293.66, 261.63, 220.0], 0.6)

func play_box_open() -> void:
    if is_muted: return
    _synthesize_sfx(0.22, 280.0, 1100.0, 0.4, false)
    _synthesize_sfx_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.5)

func play_splash_jingle() -> void:
    if is_muted: return
    _synthesize_sfx_arpeggio([261.63, 329.63, 392.0, 523.25, 659.25, 783.99, 1046.5], 1.2)

func play_menu_click() -> void:
    if is_muted: return
    _synthesize_sfx(0.08, 440.0, 880.0, 0.28, false)

func _synthesize_sfx(duration: float, start_f: float, end_f: float, vol: float, noise: bool) -> void:
    if is_muted or sfx_playback == null: return
    var frames = int(sample_rate * duration)
    var phase = 0.0

    for i in range(frames):
        var t = float(i) / float(frames)
        var freq = lerp(start_f, end_f, t)
        var env = (1.0 - t) * vol
        var sample = sin(phase) * env
        if noise:
            sample = (sample * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * env
        phase += 2.0 * PI * freq / sample_rate
        if sfx_playback.can_push_buffer(1):
            sfx_playback.push_frame(Vector2(sample, sample))

func _synthesize_sfx_arpeggio(notes: Array, total_time: float) -> void:
    if is_muted or sfx_playback == null: return
    var note_time = total_time / notes.size()
    var frames_per_note = int(sample_rate * note_time)

    for n in notes:
        var phase = 0.0
        var freq = float(n)
        for i in range(frames_per_note):
            var t = float(i) / float(frames_per_note)
            var env = sin(t * PI) * 0.35
            var sample = sin(phase) * env
            phase += 2.0 * PI * freq / sample_rate
            if sfx_playback.can_push_buffer(1):
                sfx_playback.push_frame(Vector2(sample, sample))