param(
  [ValidateSet('release', 'dwarf', 'sourcemap', 'all')]
  [string]$DebugMode = 'all'
)

$ErrorActionPreference = 'Stop'

function Assert-PathExists {
  param(
    [string]$Path,
    [string]$Description
  )

  if (-not (Test-Path $Path)) {
    throw "$Description not found: $Path"
  }
}

function Assert-SourceMapContains {
  param(
    [string]$MapPath,
    [string[]]$RequiredPatterns,
    [string]$TargetName
  )

  $map = Get-Content -Raw -Path $MapPath | ConvertFrom-Json
  if (-not $map.sources) {
    throw "Source map for $TargetName does not contain any sources: $MapPath"
  }

  foreach ($pattern in $RequiredPatterns) {
    if (-not ($map.sources | Where-Object { $_ -like $pattern })) {
      throw "Source map for $TargetName is missing expected source pattern '$pattern': $MapPath"
    }
  }
}

function Assert-WasmOutputs {
  param(
    [string]$Mode,
    [string]$TargetName,
    [string[]]$RequiredSourcePatterns = @()
  )

  $outputDir = Join-Path 'output' $Mode
  $jsPath = Join-Path $outputDir ("$TargetName.js")
  $wasmPath = Join-Path $outputDir ("$TargetName.wasm")

  Assert-PathExists -Path $jsPath -Description "$TargetName JavaScript loader"
  Assert-PathExists -Path $wasmPath -Description "$TargetName wasm binary"

  if ($Mode -eq 'sourcemap') {
    $mapPath = Join-Path $outputDir ("$TargetName.wasm.map")
    Assert-PathExists -Path $mapPath -Description "$TargetName source map"
    Assert-SourceMapContains -MapPath $mapPath -RequiredPatterns $RequiredSourcePatterns -TargetName $TargetName
  }
}

function Assert-BuildArtifacts {
  param(
    [string]$Mode
  )

  Assert-WasmOutputs -Mode $Mode -TargetName 'cmake_demo' -RequiredSourcePatterns @(
    '*src/app/main.cc',
    '*src/domain/simulation.cc',
    '*src/core/accumulator.cc',
    '*src/platform/log_sink.cc'
  )

  Assert-WasmOutputs -Mode $Mode -TargetName 'cmake_tools_demo' -RequiredSourcePatterns @(
    '*src/app/tools_main.cc',
    '*src/domain/report.cc',
    '*src/core/accumulator.cc',
    '*src/platform/log_sink.cc'
  )

  Write-Host "Validated demos/05-cmake-emcmake/output/$Mode artifacts and source maps"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
  if (-not (Get-Command emcmake -ErrorAction SilentlyContinue)) {
    throw 'emcmake not found. Please activate emsdk environment first.'
  }

  if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw 'cmake not found. Please install CMake and add it to PATH.'
  }

  $modes = if ($DebugMode -eq 'all') { @('release', 'dwarf', 'sourcemap') } else { @($DebugMode) }

  foreach ($mode in $modes) {
    $outDir = Join-Path 'output' $mode
    $buildDir = Join-Path 'build' $mode
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    & emcmake cmake -S . -B $buildDir "-DWASM_DEBUG_MODE=$mode"
    & cmake --build $buildDir
    Assert-BuildArtifacts -Mode $mode

    Write-Host "Built demos/05-cmake-emcmake/output/$mode/cmake_demo.js and cmake_tools_demo.js"
  }
}
finally {
  Pop-Location
}
