# poweroff.ps1
# ==========================================
# 🧱 Smart PowerOff Script (Docker ONLY)
# يعتمد على .env فقط (من نفس فولدر السكربت)
# يوقف:
#   1️⃣ Docker Compose stack للمشروع
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

function Test-DockerDaemonReady {
    try {
        & docker info *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Split-CommandString {
    param([Parameter(Mandatory=$true)][string]$CommandString)

   
    $tokens = @()
    $pattern = '("([^"\\]|\\.)*"|''([^''\\]|\\.)*''|\S+)'
    foreach ($m in [regex]::Matches($CommandString, $pattern)) {
        $t = $m.Value
        if (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'"))) {
            $t = $t.Substring(1, $t.Length - 2)
        }
        $tokens += $t
    }
    return $tokens
}

function Invoke-ComposeCommand {
    param([Parameter(Mandatory=$true)][string]$CommandString)

    if ([string]::IsNullOrWhiteSpace($CommandString)) {
        throw "DOCKER_COMPOSE_DOWN_CMD is empty/invalid in .env."
    }

    $parts = Split-CommandString -CommandString $CommandString
    if ($parts.Count -eq 0) { throw "DOCKER_COMPOSE_DOWN_CMD is empty/invalid." }

    $exe = $parts[0]
    $args = @()
    if ($parts.Count -gt 1) { $args = $parts[1..($parts.Count - 1)] }

    if ($exe -ieq "docker") {
        & docker @args
        return
    }

    if ($exe -ieq "docker-compose") {
        & docker-compose @args
        return
    }

    throw ("Unsupported DOCKER_COMPOSE_DOWN_CMD executable: '{0}'. Use 'docker ...' or 'docker-compose ...'." -f $exe)
}

# ======================
# LOAD .env (ONLY from script folder)
# ======================
$envPath = Join-Path $PSScriptRoot ".env"
Load-DotEnv -EnvFilePath $envPath

# ======================
# RESOLVE CONFIG (ONLY from .env)
# ======================
$ProjectPathResolved     = Require-Env -Name "PROJECT_PATH"
$ComposeDownCmdResolved  = Require-Env -Name "DOCKER_COMPOSE_DOWN_CMD"

Write-Host "🛑 Starting PowerOff sequence..." -ForegroundColor Yellow

# ======================
# STOP STACK
# ======================
Write-Section "Stopping Docker Stack"

try {
    $dockerOk = Test-DockerDaemonReady
    if (-not $dockerOk) {
        Write-Host "ℹ️ Docker is not running. Skipping compose down." -ForegroundColor Yellow
    } else {
        if (-not (Test-Path -LiteralPath $ProjectPathResolved)) {
            throw ("Project path not found: {0}" -f $ProjectPathResolved)
        }

        Set-Location $ProjectPathResolved

        Write-Host "`n📋 Containers before stopping:" -ForegroundColor Cyan
        try {
            & docker ps --format "table {{.Names}}\t{{.Status}}" 2>$null | ForEach-Object { Write-Host $_ }
        } catch {
            Write-Host "⚠️ Could not list containers." -ForegroundColor DarkYellow
        }

        if ($PSCmdlet.ShouldProcess(("{0} in {1}" -f $ComposeDownCmdResolved, $ProjectPathResolved), "Stop stack")) {
            Invoke-ComposeCommand -CommandString $ComposeDownCmdResolved
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ Docker stack stopped." -ForegroundColor Green
        } else {
            Write-Host ("⚠️ Compose down exited with code {0}." -f $LASTEXITCODE) -ForegroundColor DarkYellow
        }
    }
} catch {
    Write-Host ("❌ Unexpected error while stopping stack: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}

Write-Host "`n🏁 PowerOff complete." -ForegroundColor Red
Write-Host "   • Docker stack: stopped (if running)" -ForegroundColor Red
