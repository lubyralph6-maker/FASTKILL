# FastKill local launcher
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$here = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$exe = Join-Path $here 'FastKill.exe'
$ps1 = Join-Path $here 'FASTKILL.ps1'

if (Test-Path -LiteralPath $exe) {
    $proc = Start-Process -FilePath $exe -WorkingDirectory $here -PassThru -Wait
    exit $proc.ExitCode
}

if (Test-Path -LiteralPath $ps1) {
    & $ps1
    exit $LASTEXITCODE
}

throw "Not found: FastKill.exe or FASTKILL.ps1 in '$here'"
