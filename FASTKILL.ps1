# FASTKILL launcher
# iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

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

function Test-FkExe([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $f = Get-Item -LiteralPath $Path
        if ($f.Length -lt 1MB) { return $false }
        $fs = [IO.File]::OpenRead($Path)
        try {
            $buf = New-Object byte[] 2
            [void]$fs.Read($buf, 0, 2)
            return ([char]$buf[0] -eq 'M' -and [char]$buf[1] -eq 'Z')
        } finally { $fs.Close() }
    } catch { return $false }
}

function Download-FkExe {
    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    if (Test-FkExe $exePath) {
        Write-Host "Using cache: $exePath" -ForegroundColor Green
        return $exePath
    }

    $tmp = Join-Path $installDir 'FastKill.download'
    $err = 'Download failed'
    foreach ($url in $urls) {
        for ($i = 1; $i -le 6; $i++) {
            try {
                Write-Host "Downloading ($i/6): $url" -ForegroundColor Cyan
                if (Test-Path -LiteralPath $tmp) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                }
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers $hdr -TimeoutSec 120
                if (-not (Test-FkExe $tmp)) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    throw 'File is not a valid FastKill.exe'
                }
                if (Test-Path -LiteralPath $exePath) {
                    Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $tmp -Destination $exePath -Force
                Write-Host "Downloaded OK ($((Get-Item -LiteralPath $exePath).Length) bytes)" -ForegroundColor Green
                return $exePath
            } catch {
                $err = $_.Exception.Message
                $wait = if ($err -match '429') { [Math]::Min(90, 15 * $i) } else { 5 * $i }
                Write-Host "Retry in ${wait}s... $err" -ForegroundColor Yellow
                Start-Sleep -Seconds $wait
            }
        }
    }
    throw $err
}

function Resolve-FkExe {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $local = Join-Path $PSScriptRoot $exeName
        if (Test-FkExe $local) {
            Write-Host "Using local: $local" -ForegroundColor Green
            return $local
        }
    }
    return Download-FkExe
}

try {
    $target = Resolve-FkExe
    Write-Host "Using: $target" -ForegroundColor Green
    Write-Host 'Starting FASTKILL (Administrator)...' -ForegroundColor Cyan
    $proc = Start-Process -FilePath $target -Verb RunAs -PassThru
    if ($null -eq $proc) { throw 'UAC cancelled - click Yes' }
    Start-Sleep -Seconds 2
    if ($proc.HasExited) {
        throw "Closed immediately (exit $($proc.ExitCode)). Install VC++ x64 Redistributable / add AV exclusion."
    }
    Write-Host 'FASTKILL is running.' -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Upload FastKill.exe + FASTKILL.ps1 to GitHub repo FASTKILL (main), same folder.' -ForegroundColor Yellow
    Write-Host 'If 429: wait 15-30 min, then run once.' -ForegroundColor Yellow
}

Write-Host ''
Read-Host 'Press Enter to close'
