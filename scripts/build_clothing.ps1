param(
  [Parameter(Mandatory = $true)][string]$InputFbx,
  [Parameter(Mandatory = $true)][string]$OutputYdd,
  [Parameter(Mandatory = $true)][string]$OutputYtd
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFbx)) {
  throw "Input FBX not found: $InputFbx"
}

$blender = $env:BLENDER_PATH
if (-not $blender) {
  throw "BLENDER_PATH is not set."
}
if (-not (Test-Path $blender)) { throw "Blender executable not found: $blender" }

$scriptPath = $env:SOLLUMZ_CLOTHING_SCRIPT
if (-not $scriptPath) {
  $scriptPath = Join-Path $PSScriptRoot "sollumz_clothing_export.py"
}
if (-not (Test-Path $scriptPath)) { throw "Clothing export script missing: $scriptPath" }

& $blender --background --python "$scriptPath" -- `
  --input "$InputFbx" `
  --output-ydd "$OutputYdd" `
  --output-ytd "$OutputYtd"

if ($LASTEXITCODE -ne 0) {
  throw "Clothing Blender/Sollumz export failed with code $LASTEXITCODE"
}

if (-not (Test-Path $OutputYdd)) { throw "Expected output missing: $OutputYdd" }
if (-not (Test-Path $OutputYtd)) { throw "Expected output missing: $OutputYtd" }
