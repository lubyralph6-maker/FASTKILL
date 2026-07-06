# FASTKILL launcher - works with:
#   powershell -ExecutionPolicy Bypass -File .\FASTKILL.ps1
#   powershell -ExecutionPolicy Bypass -File .\bin\FASTKILL.ps1
#   iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

$ErrorActionPreference = 'Stop'

$exeName = 'FastKill.exe'
$installDir = Join-Path $env:LOCALAPPDATA 'FASTKILL'
$exePath = Join-Path $installDir $exeName
$exeUrl = 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe'

function Write-Status([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Get-LocalExeNearScript {
    $roots = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $roots += $PSScriptRoot
    }
    $roots += (Get-Location).Path

    foreach ($root in $roots | Select-Object -Unique) {
        $candidates = @(
            (Join-Path $root $exeName),
            (Join-Path $root 'bin\FastKill.exe'),
            (Join-Path $root 'bin\FASTKILL.exe')
        )
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    return $null
}

function Get-CachedOrDownloadedExe {
    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $exePath) {
        return $exePath
    }

    Write-Status "Downloading: $exeUrl" Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
    Write-Status 'Downloaded' Green

    if (-not (Test-Path -LiteralPath $exePath)) {
        throw 'Download failed - FastKill.exe not found after download.'
    }

    return $exePath
}

function Resolve-ExePath {
    $local = Get-LocalExeNearScript
    if ($null -ne $local) {
        return $local
    }
    return Get-CachedOrDownloadedExe
}

try {
    $targetExe = Resolve-ExePath
    if ([string]::IsNullOrWhiteSpace($targetExe)) {
        throw 'Could not resolve FastKill.exe path.'
    }

    Write-Status "Using: $targetExe" Green
    Write-Status 'Starting FASTKILL V.1 (Administrator)...' Cyan

    $proc = Start-Process -FilePath $targetExe -Verb RunAs -PassThru
    if ($null -eq $proc) {
        throw 'Start-Process returned null.'
    }

    Start-Sleep -Seconds 2
    if ($proc.HasExited) {
        throw "FastKill closed immediately (exit $($proc.ExitCode)). Run as Administrator and check antivirus exclusion."
    }

    Write-Status 'FASTKILL is running.' Green
    Write-Status 'Finished' Green
}
catch {
    Write-Status "Error: $($_.Exception.Message)" Red
    Write-Status 'Fix: upload FastKill.exe to GitHub main branch, or copy exe + ps1 in same folder.' Yellow
}

Write-Host ''
Read-Host 'Press Enter to close'
