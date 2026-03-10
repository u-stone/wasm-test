param(
  [ValidateSet('release', 'dwarf', 'sourcemap', 'all')]
  [string]$DebugMode = 'all'
)

$ErrorActionPreference = 'Stop'
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

    $debugFlags = switch ($mode) {
      'release' { '-O2' }
      'dwarf' { '-O0 -g' }
      'sourcemap' { '-O1 -gsource-map' }
    }

    & emcmake cmake -S . -B $buildDir "-DWASM_DEBUG_MODE=$mode" "-DWASM_DEBUG_FLAGS=$debugFlags"
    & cmake --build $buildDir --target cmake_demo

    Write-Host "Built demos/05-cmake-emcmake/output/$mode/cmake_demo.js"
  }
}
finally {
  Pop-Location
}
