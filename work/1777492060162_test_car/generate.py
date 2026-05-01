
import bpy
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.mesh.primitive_cube_add(location=(0,0,0)); obj=bpy.context.object; obj.scale=(2.2,4.6,0.8)
bpy.ops.export_scene.fbx(filepath=r"C:\Users\bigga\OneDrive\Desktop\HUNTERS MODS STORE\hunters-mods-pipeline\work\1777492060162_test_car\out\test_car.fbx", use_selection=False)
