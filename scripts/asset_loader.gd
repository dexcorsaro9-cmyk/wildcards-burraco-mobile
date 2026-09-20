class_name AssetLoader
extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(res_path: String) -> Texture2D:
    if _cache.has(res_path):
        return _cache[res_path]

    # 1. Standard Godot resource loading (works inside PCK, Web, Android, iOS)
    if ResourceLoader.exists(res_path):
        var res = ResourceLoader.load(res_path)
        if res is Texture2D:
            _cache[res_path] = res
            return res

    # 2. FileAccess fallback for raw PNGs inside virtual res://
    if FileAccess.file_exists(res_path):
        var fa = FileAccess.open(res_path, FileAccess.READ)
        if fa != null:
            var buffer = fa.get_buffer(fa.get_length())
            var img = Image.new()
            var err = img.load_png_from_buffer(buffer)
            if err == OK:
                var tex = ImageTexture.create_from_image(img)
                _cache[res_path] = tex
                return tex

    # 3. Globalized path fallback for desktop editor
    var abs_path = ProjectSettings.globalize_path(res_path)
    if FileAccess.file_exists(abs_path):
        var img = Image.load_from_file(abs_path)
        if img != null:
            var tex = ImageTexture.create_from_image(img)
            _cache[res_path] = tex
            return tex

    return null
