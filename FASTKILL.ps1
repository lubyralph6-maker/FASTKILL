# FASTKILL - download exe then run
# iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dir  = Join-Path $env:LOCALAPPDATA 'FASTKILL'
$exe  = Join-Path $dir 'FastKill.exe'
$tmp  = Join-Path $dir 'FastKill.download'
$url  = 'https://github.com/lubyralph6-maker/FASTKILL/raw/main/FastKill.exe'
$ua   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FASTKILL/1.2'

function Is-Exe([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    try {
        $i = Get-Item -LiteralPath $p
        if ($i.Length -lt 500KB) { return $false }
        $b = New-Object byte[] 2
        $fs = [IO.File]::OpenRead($p)
        try { [void]$fs.Read($b, 0, 2) } finally { $fs.Dispose() }
        return ($b[0] -eq 0x4D -and $b[1] -eq 0x5A) # MZ
    } catch { return $false }
}

try {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not (Is-Exe $exe)) {
        Write-Host "Downloading FastKill.exe ..." -ForegroundColor Cyan
        Write-Host $url -ForegroundColor DarkGray
        $ok = $false
        for ($n = 1; $n -le 6; $n++) {
            try {
                if (Test-Path -LiteralPath $tmp) { Remove-Item $tmp -Force -EA SilentlyContinue }
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers @{ 'User-Agent' = $ua } -TimeoutSec 180
                if (-not (Is-Exe $tmp)) { throw 'Downloaded file is not a valid .exe (upload FastKill.exe to GitHub)' }
                Move-Item -LiteralPath $tmp -Destination $exe -Force
                Write-Host "Downloaded: $exe ($((Get-Item $exe).Length) bytes)" -ForegroundColor Green
                $ok = $true
                break
            } catch {
                $msg = $_.Exception.Message
                $wait = if ($msg -match '429') { 20 * $n } else { 4 * $n }
                Write-Host "[$n/6] fail: $msg" -ForegroundColor Yellow
                Write-Host "wait ${wait}s ..." -ForegroundColor Yellow
                Start-Sleep -Seconds $wait
            }
        }
        if (-not $ok) { throw 'Cannot download FastKill.exe - upload FastKill.exe to GitHub repo FASTKILL/main' }
    } else {
        Write-Host "Using cache: $exe" -ForegroundColor Green
    }

    Write-Host 'Starting as Administrator...' -ForegroundColor Cyan
    $p = Start-Process -FilePath $exe -Verb RunAs -PassThru
    if ($null -eq $p) { throw 'UAC cancelled' }
    Start-Sleep -Seconds 2
    if ($p.HasExited) { throw "Exe closed immediately (exit $($p.ExitCode))" }
    Write-Host 'FASTKILL is running.' -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Read-Host 'Press Enter to close'
