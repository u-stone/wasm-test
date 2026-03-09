param(
  [ValidateSet('release', 'dwarf', 'sourcemap', 'all')]
  [string]$DebugMode = 'all'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $repoRoot
try {
  $scripts = @(
    'demos/01-pthreads/build.ps1',
    'demos/02-asyncify/build.ps1',
    'demos/03-manual-workers/build.ps1',
    'demos/04-cpp20-coroutine/build.ps1',
    'demos/extra-interop/closure/build.ps1',
    'demos/extra-interop/type-conversion/build.ps1'
  )

  foreach ($script in $scripts) {
    Write-Host "==> Running $script"
    & powershell -ExecutionPolicy Bypass -File $script -DebugMode $DebugMode
  }

  Write-Host "All demos built successfully. Mode: $DebugMode"
}
finally {
  Pop-Location
}
