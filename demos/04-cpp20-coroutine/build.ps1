param(
  [ValidateSet('release', 'dwarf', 'sourcemap', 'all')]
  [string]$DebugMode = 'all'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
  if (-not (Get-Command em++ -ErrorAction SilentlyContinue)) {
    throw 'em++ not found. Please activate emsdk environment first.'
  }

  $modes = if ($DebugMode -eq 'all') { @('release', 'dwarf', 'sourcemap') } else { @($DebugMode) }

  foreach ($mode in $modes) {
    $outDir = Join-Path 'output' $mode
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $debugFlags = switch ($mode) {
      'release' { @('-O2') }
      'dwarf' { @('-O1', '-g') }
      'sourcemap' { @('-O1', '-gsource-map') }
    }

    $args = @(
      'src/main.cc', '-o', (Join-Path $outDir 'coroutine.js')
    ) + $debugFlags + @(
      '-std=c++20',
      '-s', 'EXPORTED_FUNCTIONS=["_run_coroutine_demo"]',
      '-s', 'EXPORTED_RUNTIME_METHODS=["ccall"]'
    )

    & em++ @args
    Write-Host "Built demos/04-cpp20-coroutine/output/$mode/coroutine.js"
  }
}
finally {
  Pop-Location
}
