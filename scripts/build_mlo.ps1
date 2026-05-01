param(
  [Parameter(Mandatory = $true)][string]$InputFbx,
  [Parameter(Mandatory = $true)][string]$OutputYmap
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFbx)) {
  throw "Input FBX not found: $InputFbx"
}

# TODO: Point this to your real YMAP builder wrapper.
# Typical flow: convert FBX to map entities -> compile to .ymap using your map toolchain.
$builder = $env:MLO_BUILDER_EXE
if (-not $builder) {
  throw "MLO_BUILDER_EXE is not set. Set it to your YMAP builder executable."
}

& $builder "--input" "$InputFbx" "--out-ymap" "$OutputYmap"
if ($LASTEXITCODE -ne 0) {
  throw "MLO builder failed with code $LASTEXITCODE"
}

if (-not (Test-Path $OutputYmap)) { throw "Expected output missing: $OutputYmap" }
