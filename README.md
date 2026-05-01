# Hunters Mods Binary Pipeline

This service fabricates GTA/FiveM binary assets by orchestrating:
- Blender (headless) for geometry generation
- Sollumz (inside Blender) for `.yft/.ydd/.ytd` export
- External map builder for `.ymap`

## Endpoints

- `GET /` toolchain status
- `POST /api/pipeline/fabricate`
  - body: `{ "type": "vehicle|mlo|clothing", "name": "asset_name" }`

## Required Environment Variables

- `BLENDER_PATH` absolute path to Blender executable
- `MLO_BUILDER_EXE` executable that emits `.ymap` from FBX/map source
- Blender must have Sollumz installed and enabled in the same user profile used by headless Blender.

Optional:
- `PIPELINE_PORT` default `3010`
- `PIPELINE_WORKDIR` default `./work`
- `VEHICLE_BUILDER_SCRIPT` default `./scripts/build_vehicle.ps1`
- `CLOTHING_BUILDER_SCRIPT` default `./scripts/build_clothing.ps1`
- `MLO_BUILDER_SCRIPT` default `./scripts/build_mlo.ps1`
- `SOLLUMZ_VEHICLE_SCRIPT` default `./scripts/sollumz_vehicle_export.py`
- `SOLLUMZ_CLOTHING_SCRIPT` default `./scripts/sollumz_clothing_export.py`
- `SOLLUMZ_ADDON_DIR` folder that contains the Sollumz addon (helps headless Blender find it)

## Wrapper Scripts

Wrapper scripts are in `scripts/` and receive standardized args:

- Vehicle: `-InputFbx -OutputYft -OutputYtd`
- Clothing: `-InputFbx -OutputYdd -OutputYtd`
- MLO: `-InputFbx -OutputYmap`

Vehicle/clothing wrappers call Blender with the bundled Sollumz export scripts.
MLO wrapper still calls your map builder executable.

## If you get "Sollumz addon is not installed/enabled"

Headless Blender may use a different user profile than the Blender UI.

Fix options:
1) Open Blender UI once, install Sollumz, enable it, and **Save Preferences**
2) Or set `SOLLUMZ_ADDON_DIR` to the directory that contains the Sollumz addon folder (so headless Blender can find it)
