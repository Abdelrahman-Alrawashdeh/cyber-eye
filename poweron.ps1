# poweron.ps1
# ==========================================
#  PowerOn Script for Cyber-Eye (Docker ONLY)
# يعتمد على .env فقط (من نفس فولدر السكربت)
# ==========================================

[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host "`n===== $Text =====" -ForegroundColor Cyan
}

function Load-DotEnv {
    param([Parameter(Mandatory=$true)][string]$EnvFilePath)

    if (-not (Test-Path -LiteralPath $EnvFilePath)) {
        throw ".env not found at: $EnvFilePath"
    }

    Get-Content -LiteralPath $EnvFilePath | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        if ($line.StartsWith("#")) { return }

       
        if ($line -match '^\s*([^=]+?)\s*=\s*(.*)\s*$') {
            $name  = $matches[1].Trim()
            $value = $matches[2].Trim()

           
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

          
            Set-Item -Path ("Env:{0}" -f $name) -Value $value
        }
    }
}

function Require-Env {
    param([Parameter(Mandatory=$true)][string]$Name)

    $v = (Get-Item -Path ("Env:{0}" -f $Name) -ErrorAction SilentlyContinue).Value
    if ([string]::IsNullOrWhiteSpace($v)) {
        throw "Missing required .env variable: $Name"
    }
    return $v
}

function Get-EnvIntOrThrow {
    param([Parameter(Mandatory=$true)][string]$Name)

    $raw = Require-Env -Name $Name
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) { return $parsed }

    throw ("Invalid integer in .env for {0}: '{1}'" -f $Name, $raw)
}

function Test-DockerCliAvailable {
    try { & docker --version *> $null; return $true } catch { return $false }
}

function Ensure-DockerDesktopRunning {
    param(
        [Parameter(Mandatory=$true)][string]$DockerDesktopPath,
        [Parameter(Mandatory=$true)][int]$InitialWaitSeconds
    )

    Write-Section "Checking Docker Desktop status"
    $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

    if (-not $dockerProcess) {
        Write-Host "`n⚙️  Docker Desktop not running. Starting it...`n" -ForegroundColor Yellow

        if (-not (Test-Path -LiteralPath $DockerDesktopPath)) {
            Write-Host ("❌ Docker Desktop executable not found at: {0}" -f $DockerDesktopPath) -ForegroundColor Red
            throw "Docker Desktop not found."
        }

        Start-Process -FilePath $DockerDesktopPath -WindowStyle Hidden | Out-Null
        Write-Host ("⌛ Waiting {0} seconds for Docker Desktop to boot..." -f $InitialWaitSeconds) -ForegroundColor Yellow
        Start-Sleep -Seconds $InitialWaitSeconds
    } else {
        Write-Host "`n✅ Docker Desktop is already running." -ForegroundColor Green
    }
}

function Wait-DockerDaemonReady {
    param([int]$MaxTries, [int]$RetrySeconds)

    Write-Section "Waiting for Docker daemon"
    $dockerReady = $false

    for ($i = 0; $i -lt $MaxTries; $i++) {
        $tryNum = $i + 1
        try {
            & docker info *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n🐳 Docker daemon is ready." -ForegroundColor Green
                $dockerReady = $true
                break
            } else {
                Write-Host ("⌛ Docker not ready yet (exit code: {0})... (try {1}/{2})" -f $LASTEXITCODE, $tryNum, $MaxTries) -ForegroundColor Yellow
            }
        } catch {
            Write-Host ("⚠️ Error calling 'docker info': {0} (try {1}/{2})" -f $_.Exception.Message, $tryNum, $MaxTries) -ForegroundColor Yellow
        }
        Start-Sleep -Seconds $RetrySeconds
    }

    if (-not $dockerReady) {
        $totalWait = $MaxTries * $RetrySeconds
        throw ("Docker failed to become ready after {0} seconds." -f $totalWait)
    }
}

function Invoke-DockerComposeCommand {
    param([Parameter(Mandatory=$true)][string]$CommandString)

    if ([string]::IsNullOrWhiteSpace($CommandString)) {
        throw "DOCKER_COMPOSE_CMD is empty/invalid in .env."
    }

    
    $tokens = @()
    $pattern = '("([^"\\]|\\.)*"|''([^''\\]|\\.)*''|\S+)'
    foreach ($m in [regex]::Matches($CommandString, $pattern)) {
        $t = $m.Value
        if (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'"))) {
            $t = $t.Substring(1, $t.Length - 2)
        }
        $tokens += $t
    }

    if ($tokens.Count -lt 1) { throw "DOCKER_COMPOSE_CMD is empty/invalid." }

    $exe  = $tokens[0]
    $args = @()
    if ($tokens.Count -gt 1) { $args = $tokens[1..($tokens.Count - 1)] }

    if ($exe -ieq "docker") { & docker @args; return }
    if ($exe -ieq "docker-compose") { & docker-compose @args; return }

    throw ("Unsupported DOCKER_COMPOSE_CMD executable: '{0}'. Use 'docker ...' or 'docker-compose ...'." -f $exe)
}

function Start-CyberEyeStack {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectPath,
        [Parameter(Mandatory=$true)][string]$ComposeCmd
    )

    Write-Section "Starting Cyber-Eye Docker Stack"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $ProjectPath)) {
        Write-Host ("❌ Project path not found: {0}" -f $ProjectPath) -ForegroundColor Red
        throw "Project path not found."
    }

    Set-Location $ProjectPath

    $startTime = Get-Date
    try {
        if ($PSCmdlet.ShouldProcess(("{0} in {1}" -f $ComposeCmd, $ProjectPath), "Start Cyber-Eye stack")) {
            Invoke-DockerComposeCommand -CommandString $ComposeCmd
        }
    } catch {
        Write-Host ("❌ Error while running compose command: {0}" -f $_.Exception.Message) -ForegroundColor Red
        throw
    }

    $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    Write-Host ("`n✅ Cyber-Eye stack started successfully in {0} seconds!" -f $elapsed) -ForegroundColor Green
}

function Show-ContainerSummary {
    Write-Section "Container status"
    Write-Host ""

    try {
        $output = & docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
            Write-Host "ℹ️ No running containers found." -ForegroundColor Yellow
        } else {
            $output | ForEach-Object { Write-Host $_ }
        }
    } catch {
        Write-Host ("⚠️ Unable to list containers: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

# ======================
# LOAD .env (ONLY from script folder)
# ======================
$envPath = Join-Path $PSScriptRoot ".env"

Load-DotEnv -EnvFilePath $envPath

# ======================
# Resolve config (ONLY from .env)
# ======================
$ProjectPath        = Require-Env -Name "PROJECT_PATH"
$DockerDesktopPath  = Require-Env -Name "DOCKER_DESKTOP_PATH"
$InitialDockerWait  = Get-EnvIntOrThrow -Name "INITIAL_DOCKER_WAIT"
$MaxDockerTries     = Get-EnvIntOrThrow -Name "MAX_DOCKER_TRIES"
$DockerRetrySeconds = Get-EnvIntOrThrow -Name "DOCKER_RETRY_SECONDS"
$DockerComposeCmd   = Require-Env -Name "DOCKER_COMPOSE_CMD"
$OpenUrl            = (Get-Item -Path "Env:OPEN_URL" -ErrorAction SilentlyContinue).Value

# ======================
# MAIN FLOW
# ======================
try {
    if (-not (Test-DockerCliAvailable)) {
        Write-Host "⚠️ 'docker' CLI is not available in PATH. Make sure Docker Desktop is installed and PATH is configured." -ForegroundColor Red
        throw "'docker' CLI not found."
    }

    Ensure-DockerDesktopRunning -DockerDesktopPath $DockerDesktopPath -InitialWaitSeconds $InitialDockerWait
    Wait-DockerDaemonReady -MaxTries $MaxDockerTries -RetrySeconds $DockerRetrySeconds

    Start-CyberEyeStack -ProjectPath $ProjectPath -ComposeCmd $DockerComposeCmd
    Show-ContainerSummary

    Write-Host "`n✅ Done." -ForegroundColor Green

    if (-not [string]::IsNullOrWhiteSpace($OpenUrl)) {
        Start-Process $OpenUrl
    }
} catch {
    Write-Host ("`n❌ PowerOn script failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
