class_name AssetLoader
extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(res_path: String) -> Texture2D:
    if _cache.has(res_path):
        return _cache[res_path]

    var abs_path = ProjectSettings.globalize_path(res_path)
    if FileAccess.file_exists(abs_path):
        var img = Image.load_from_file(abs_path)
        if img != null:
            var tex = ImageTexture.create_from_image(img)
            _cache[res_path] = tex
            return tex
    return null
