# FastKill local launcher
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$here = $null
if ($PSScriptRoot) {
    $here = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $here = (Get-Location).Path
}

$exe = Join-Path $here 'FastKill.exe'
$ps1 = Join-Path $here 'FASTKILL.ps1'

if (Test-Path -LiteralPath $exe) {
    $proc = Start-Process -FilePath $exe -WorkingDirectory $here -PassThru -Wait
    exit $proc.ExitCode
}

# Avoid re-entering this launcher if we are FASTKILL.ps1 itself
$self = $MyInvocation.MyCommand.Path
if ((Test-Path -LiteralPath $ps1) -and ($self -ne $ps1)) {
    & $ps1
    exit $LASTEXITCODE
}

throw @"
FastKill.exe not found in: $here

How to run:
1. Put this .ps1 in the same folder as FastKill.exe
2. Run locally, for example:
   powershell -NoProfile -ExecutionPolicy Bypass -File .\FastKill-Launcher.ps1

Do not use: iex (irm 'https://...')
"@
