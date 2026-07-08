# FASTKILL launcher - works with:
#   powershell -File .\FASTKILL.ps1
#   iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$exeName = 'FastKill.exe'
$installDir = Join-Path $env:LOCALAPPDATA 'FASTKILL'
$exePath = Join-Path $installDir $exeName
$hdr = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FASTKILL/1.0' }
$urls = @(
    "https://github.com/lubyralph6-maker/FASTKILL/raw/main/$exeName",
    "https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/$exeName"
)

function Ok-Exe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $b = [IO.File]::ReadAllBytes($Path)
        return ($b.Length -gt 1MB) -and ([Text.Encoding]::ASCII.GetString($b, 0, 2) -eq 'MZ')
    } catch { return $false }
}

function Get-Exe {
    foreach ($p in @(
        (Join-Path $PSScriptRoot $exeName),
        (Join-Path (Get-Location) $exeName)
    )) {
        if (Ok-Exe $p) {
            Write-Host "Using local: $p" -ForegroundColor Green
            return (Resolve-Path -LiteralPath $p).Path
        }
    }

    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }
    if (Ok-Exe $exePath) {
        Write-Host "Using cache: $exePath" -ForegroundColor Green
        return $exePath
    }

    $tmp = Join-Path $installDir 'FastKill.download'
    $err = 'Download failed'
    foreach ($url in $urls) {
        for ($i = 1; $i -le 5; $i++) {
            try {
                Write-Host "Downloading ($i/5): $url" -ForegroundColor Cyan
                if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -EA SilentlyContinue }
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers $hdr -TimeoutSec 120
                if (-not (Ok-Exe $tmp)) { throw 'Invalid exe (not MZ / too small)' }
                Move-Item -LiteralPath $tmp -Destination $exePath -Force
                Write-Host 'Downloaded' -ForegroundColor Green
                return $exePath
            } catch {
                $err = $_.Exception.Message
                $wait = if ($err -match '429') { 20 * $i } else { 5 * $i }
                Write-Host "Retry in ${wait}s... $err" -ForegroundColor Yellow
                Start-Sleep -Seconds $wait
            }
        }
    }
    throw $err
}

try {
    $target = Get-Exe
    Write-Host "Using: $target" -ForegroundColor Green
    Write-Host 'Starting FASTKILL (Administrator)...' -ForegroundColor Cyan
    $proc = Start-Process -FilePath $target -Verb RunAs -PassThru
    if ($null -eq $proc) { throw 'UAC cancelled or Start-Process failed.' }
    Start-Sleep -Seconds 2
    if ($proc.HasExited) {
        throw "Closed immediately (exit $($proc.ExitCode)). Install VC++ x64 Redistributable / add AV exclusion."
    }
    Write-Host 'FASTKILL is running.' -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Fix: upload FastKill.exe + FASTKILL.ps1 to GitHub repo FASTKILL (main), same folder.' -ForegroundColor Yellow
    Write-Host 'If 429: wait 15-30 min, run once (do not spam).' -ForegroundColor Yellow
}

Write-Host ''
Read-Host 'Press Enter to close'
