# iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$FkCdn  = 'https://cdn.jsdelivr.net/gh/lubyralph6-maker/FASTKILL@main'
$FkRaw  = 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main'
$FkExe  = 'FastKill.exe'
$FkLink = "$FkRaw/FASTKILL.ps1"

try {
    if (-not (Test-Path 'HKCU:\Software\Microsoft\PowerShell\PSReadLine')) {
        New-Item 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' -Force | Out-Null
    }
    Set-ItemProperty 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' HistorySaveStyle 2 -Type DWord -Force
    Import-Module PSReadLine -ErrorAction SilentlyContinue | Out-Null
    Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue
} catch {}

$hdr = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FASTKILL/2.1'
    'Accept'     = '*/*'
}

$urls = @(
    "$FkCdn/$FkExe",
    "$FkCdn/bin/$FkExe",
    "$FkRaw/$FkExe",
    "https://github.com/lubyralph6-maker/FASTKILL/raw/main/$FkExe",
    "https://github.com/lubyralph6-maker/FASTKILL/raw/main/bin/$FkExe"
)

$workDir = $null
$exePath = $null
$proc    = $null

$legacyDir = Join-Path $env:LOCALAPPDATA 'FASTKILL'
if (-not [string]::IsNullOrWhiteSpace($legacyDir) -and (Test-Path -LiteralPath $legacyDir)) {
    Remove-Item -LiteralPath $legacyDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Write-Fk([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Test-FkExe([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $f = Get-Item -LiteralPath $Path
        if ($f.Length -lt 4MB) { return $false }
        $b = [IO.File]::ReadAllBytes($Path)
        if ($b.Length -lt 512) { return $false }
        if ([Text.Encoding]::ASCII.GetString($b, 0, 2) -ne 'MZ') { return $false }
        $o = [BitConverter]::ToInt32($b, 0x3C)
        if ($o -lt 0 -or ($o + 0x200) -gt $b.Length) { return $false }
        if ([Text.Encoding]::ASCII.GetString($b, $o, 4) -ne "PE`0`0") { return $false }
        return ([BitConverter]::ToUInt16($b, $o + 4) -eq 0x8664)
    } catch {
        return $false
    }
}

function Remove-FkWorkDir([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Invoke-FkDownload {
    param([string]$Url, [string]$OutFile)

    $wc = New-Object System.Net.WebClient
    foreach ($key in $hdr.Keys) { $wc.Headers[$key] = $hdr[$key] }
    $wc.DownloadFile($Url, $OutFile)
}

function Get-FkLocalExe {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $candidates += (Join-Path $PSScriptRoot "bin\$FkExe")
        $candidates += (Join-Path $PSScriptRoot $FkExe)
    }
    $here = (Get-Location).Path
    if (-not [string]::IsNullOrWhiteSpace($here)) {
        $candidates += (Join-Path $here "bin\$FkExe")
        $candidates += (Join-Path $here $FkExe)
    }

    foreach ($local in $candidates) {
        if (Test-FkExe $local) {
            Write-Fk "Using local: $local" Green
            return (Resolve-Path -LiteralPath $local).Path
        }
    }
    return $null
}

function Get-FkTempExe {
    if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
        throw 'TEMP folder not found'
    }

    $script:workDir = Join-Path $env:TEMP ("FK_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null

    $tmp = Join-Path $workDir "$FkExe.download"
    $out = Join-Path $workDir $FkExe
    $lastError = 'Download failed'

    foreach ($url in $urls) {
        foreach ($try in 1..4) {
            try {
                Write-Fk "Downloading ($try/4): $url" Cyan
                if (Test-Path -LiteralPath $tmp) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                }

                try {
                    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers $hdr -TimeoutSec 120
                } catch {
                    Invoke-FkDownload -Url $url -OutFile $tmp
                }

                if (-not (Test-FkExe $tmp)) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    throw 'Downloaded file is not a valid 64-bit exe'
                }

                if (Test-Path -LiteralPath $out) {
                    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $tmp -Destination $out -Force

                Write-Fk "Downloaded OK ($((Get-Item -LiteralPath $out).Length) bytes)" Green
                return $out
            } catch {
                $lastError = $_.Exception.Message
                $wait = if ($lastError -match '429|Too Many Requests') { 15 * $try } else { 5 * $try }
                Write-Fk "Retry in ${wait}s: $lastError" Yellow
                Start-Sleep -Seconds $wait
            }
        }
    }

    throw $lastError
}

try {
    $local = Get-FkLocalExe
    if ($local) {
        $exePath = $local
    } else {
        $exePath = Get-FkTempExe
    }

    if ([string]::IsNullOrWhiteSpace($exePath)) {
        throw 'FastKill.exe not found'
    }

    Write-Fk 'Starting FASTKILL (Administrator)...' Cyan
    $proc = Start-Process -FilePath $exePath -Verb RunAs -PassThru
    if ($null -eq $proc) { throw 'RunAs failed - click Yes on UAC' }
    Start-Sleep -Seconds 3
    if ($proc.HasExited) { throw "FastKill closed immediately (exit $($proc.ExitCode))" }
    Write-Fk 'FASTKILL running' Green
}
catch {
    Write-Fk "Error: $($_.Exception.Message)" Red
    Write-Fk 'Fix: upload FastKill.exe to GitHub main branch, or copy exe + ps1 in same folder.' Yellow
    Write-Fk "Run: iex (irm '$FkLink')" Yellow
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($workDir)) {
        if ($proc -and -not $proc.HasExited) {
            Start-Sleep -Seconds 2
        }
        Remove-FkWorkDir -Path $workDir
    }
}

if ($Host.Name -eq 'ConsoleHost') {
    Write-Fk 'Press Enter to close:' Gray
    Read-Host | Out-Null
}
