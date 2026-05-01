import argparse
import os
import shutil
import sys

import addon_utils
import bpy


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-ydd", required=True)
    parser.add_argument("--output-ytd", required=True)
    return parser.parse_args(argv)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_sollumz():
    addon_dir = os.environ.get("SOLLUMZ_ADDON_DIR")
    if addon_dir and os.path.isdir(addon_dir) and addon_dir not in sys.path:
        sys.path.append(addon_dir)

    addon_utils.modules_refresh()

    for module_name in ("sollumz", "Sollumz"):
        try:
            addon_utils.enable(module_name, default_set=True, persistent=True)
        except Exception:
            pass

    loaded = any(m.__name__ in ("sollumz", "Sollumz") for m in addon_utils.modules())
    if not loaded:
        raise RuntimeError(
            "Sollumz addon is not installed/enabled for this Blender user profile.\n"
            "Fix: Install/enable Sollumz in Blender, OR set SOLLUMZ_ADDON_DIR to the folder that contains the Sollumz addon."
        )


def set_selected_sollum_type(type_name: str):
    scene = bpy.context.scene
    enum_items = scene.bl_rna.properties["all_sollum_type"].enum_items
    valid = {item.identifier for item in enum_items}
    if type_name not in valid:
        raise RuntimeError(f'Sollum type "{type_name}" is unavailable.')
    scene.all_sollum_type = type_name
    bpy.ops.sollumz.setsollumtype()


def import_fbx(input_fbx: str):
    bpy.ops.import_scene.fbx(filepath=input_fbx)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects found after FBX import.")
    return meshes


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def copy_first_with_ext(out_dir: str, ext: str, out_file: str):
    matches = [f for f in os.listdir(out_dir) if f.lower().endswith(ext)]
    if not matches:
        return False
    shutil.copyfile(os.path.join(out_dir, matches[0]), out_file)
    return True


def main():
    args = parse_args()
    out_dir = os.path.dirname(os.path.abspath(args.output_ydd))
    os.makedirs(out_dir, exist_ok=True)

    ensure_sollumz()
    clear_scene()
    meshes = import_fbx(args.input)

    # Minimal clothing hierarchy: DRAWABLE_DICTIONARY -> DRAWABLE -> DRAWABLE_MODEL.
    select_only(meshes)
    set_selected_sollum_type("DRAWABLE_MODEL")
    bpy.ops.sollumz.createdrawable()
    drawable = bpy.context.view_layer.objects.active
    for mesh in meshes:
        mesh.parent = drawable

    select_only([drawable])
    set_selected_sollum_type("DRAWABLE")
    bpy.ops.sollumz.createdrawabledict()
    ydd_root = bpy.context.view_layer.objects.active
    drawable.parent = ydd_root
    set_selected_sollum_type("DRAWABLE_DICTIONARY")

    select_only([ydd_root])
    result = bpy.ops.sollumz.export_assets(
        directory=out_dir,
        direct_export=True,
        use_custom_settings=True,
        limit_to_selected=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Sollumz export failed: {result}")

    if not copy_first_with_ext(out_dir, ".ydd", args.output_ydd):
        raise RuntimeError("No .ydd produced. Ensure Sollumz native export provider is installed.")
    if not copy_first_with_ext(out_dir, ".ytd", args.output_ytd):
        raise RuntimeError("No .ytd produced. Ensure materials/textures are present and native export is enabled.")


if __name__ == "__main__":
    main()
