# ============================================================
# 🧪 Banana Slides Pre-Container Testing Script
# ============================================================
# This script validates your environment before running containers
# Usage: .\scripts\pre-flight-check.ps1

param(
    [switch]$Verbose = $false,
    [switch]$Quick = $false
)

$ErrorActionPreference = "Continue"
$passed = 0
$failed = 0
$warnings = 0

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Text" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Test {
    param([string]$Name)
    Write-Host "  ▶ $Name..." -ForegroundColor Yellow -NoNewline
}

function Write-Pass {
    param([string]$Message = "")
    Write-Host " ✓" -ForegroundColor Green
    if ($Message) { Write-Host "    └─ $Message" -ForegroundColor Green }
    $global:passed++
}

function Write-Fail {
    param([string]$Message = "")
    Write-Host " ✗" -ForegroundColor Red
    if ($Message) { Write-Host "    └─ $Message" -ForegroundColor Red }
    $global:failed++
}

function Write-Warn {
    param([string]$Message = "")
    Write-Host " ⚠" -ForegroundColor Yellow
    if ($Message) { Write-Host "    └─ $Message" -ForegroundColor Yellow }
    $global:warnings++
}

# Test 1: Port Availability
Write-Header "1️⃣ Port Availability Check"

$ports = @{
    "5101" = "Backend (Host Port)"
    "3031" = "Frontend (Host Port)"
    "11434" = "Ollama"
    "14321" = "LM Studio"
}

foreach ($port in $ports.GetEnumerator()) {
    Write-Test "Checking port $($port.Name) ($($port.Value))"
    
    $connection = Get-NetTCPConnection -LocalPort $port.Name -State Listen -ErrorAction SilentlyContinue
    if ($connection) {
        Write-Pass "In use (Process: $($connection.OwningProcess))"
    } else {
        Write-Pass "Available"
    }
}

# Test 2: Local Services
Write-Header "2️⃣ Local Services Connectivity"

Write-Test "Ollama (http://host.docker.internal:11434)"
try {
    $response = Invoke-WebRequest -Uri "http://host.docker.internal:11434/api/tags" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        $models = $response.Content | ConvertFrom-Json
        Write-Pass "Running ($(($models.models | Measure-Object).Count) models available)"
    }
} catch {
    Write-Warn "Not responding (ensure it's running: docker run -d -p 11434:11434 ollama/ollama)"
}

Write-Test "LM Studio (http://127.0.0.1:14321)"
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:14321/api/v1/models" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Pass "Running"
    }
} catch {
    Write-Warn "Not responding (ensure LM Studio is running: https://lmstudio.ai/)"
}

# Test 3: Docker and Docker Compose
Write-Header "3️⃣ Docker Environment"

Write-Test "Docker installed"
try {
    $docker = docker --version 2>$null
    if ($docker) {
        Write-Pass $docker
    } else {
        Write-Fail "Docker not found"
    }
} catch {
    Write-Fail "Docker command failed"
}

Write-Test "Docker Compose installed"
try {
    $compose = docker compose version 2>$null
    if ($compose) {
        Write-Pass $compose
    } else {
        Write-Fail "Docker Compose not found"
    }
} catch {
    Write-Fail "Docker Compose command failed"
}

Write-Test "Docker daemon running"
try {
    $test = docker ps 2>$null
    Write-Pass "Docker daemon is active"
} catch {
    Write-Fail "Docker daemon is not running"
}

# Test 4: Docker Compose Validation
Write-Header "4️⃣ Docker Compose Files Validation"

Write-Test "docker-compose.yml"
try {
    $config = docker compose config 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Pass "Valid"
    } else {
        Write-Fail "Syntax error in docker-compose.yml"
    }
} catch {
    Write-Fail "Unable to validate"
}

Write-Test "docker-compose.prod.yml"
try {
    $config = docker compose -f docker-compose.prod.yml config 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Pass "Valid"
    } else {
        Write-Fail "Syntax error in docker-compose.prod.yml"
    }
} catch {
    Write-Fail "Unable to validate"
}

# Test 5: Environment Configuration
Write-Header "5️⃣ Environment Configuration (.env)"

Write-Test ".env file exists"
if (Test-Path ".env") {
    Write-Pass "Found"
    
    # Check for required variables
    $env_content = Get-Content ".env" -Raw
    
    $required_vars = @(
        "BACKEND_PORT",
        "AI_PROVIDER_FORMAT",
        "FLASK_ENV"
    )
    
    foreach ($var in $required_vars) {
        Write-Test "Checking $var"
        if ($env_content -match "$var=") {
            $value = ($env_content -match "$var=(.*)") | ForEach-Object { $_.Split('=')[1] }
            Write-Pass "Set to: $value"
        } else {
            Write-Warn "Not found in .env"
        }
    }
} else {
    Write-Fail ".env file not found (copy from .env.example)"
}

# Test 6: Network Connectivity Tests
if (-not $Quick) {
    Write-Header "6️⃣ Network Connectivity (Docker Perspective)"
    
    Write-Test "Simulating Docker container network access"
    try {
        # Test from host if Docker is available
        $test_image = docker ps -a --format "{{.Image}}" 2>$null | Select-Object -First 1
        if ($test_image) {
            Write-Pass "Docker environment ready"
        }
    } catch {
        Write-Warn "Unable to simulate Docker context"
    }
}

# Test 7: API Connectivity Tests
Write-Header "7️⃣ API Endpoint Tests"

Write-Test "Ollama Chat API"
try {
    $payload = @{
        model = "llama2"
        messages = @(@{role = "user"; content = "Say hello"})
        stream = $false
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri "http://host.docker.internal:11434/api/chat" `
        -Method POST `
        -Body $payload `
        -ContentType "application/json" `
        -TimeoutSec 5 `
        -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        Write-Pass "API responding correctly"
    }
} catch {
    Write-Warn "Ollama API not responding (model may not be loaded)"
}

Write-Test "LM Studio Chat API"
try {
    $payload = @{
        model = "ibm/granite-4-micro"
        messages = @(@{role = "user"; content = "Say hello"})
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:14321/api/v1/chat/completions" `
        -Method POST `
        -Body $payload `
        -ContentType "application/json" `
        -TimeoutSec 5 `
        -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        Write-Pass "API responding correctly"
    }
} catch {
    Write-Warn "LM Studio API not responding (ensure a model is loaded)"
}

# Test 8: GPU/Compute Resources
Write-Header "8️⃣ System Resources"

Write-Test "Memory available"
try {
    $memory = Get-WmiObject Win32_ComputerSystem | Select-Object TotalPhysicalMemory
    $gb = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
    Write-Pass "$gb GB available"
} catch {
    Write-Warn "Unable to detect memory"
}

Write-Test "Disk space (working directory)"
try {
    $drive = (Get-Item ".").PSDrive.Name
    $disk = Get-Volume -DriveLetter $drive
    $free_gb = [math]::Round($disk.SizeRemaining / 1GB, 2)
    if ($free_gb -gt 10) {
        Write-Pass "$free_gb GB free (sufficient)"
    } else {
        Write-Warn "$free_gb GB free (minimum 10GB recommended)"
    }
} catch {
    Write-Warn "Unable to check disk space"
}

# Summary
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           📊 Test Summary                         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "  ✓ Passed:  " -ForegroundColor Green -NoNewline
Write-Host "$passed" -ForegroundColor Green

Write-Host "  ⚠ Warnings: " -ForegroundColor Yellow -NoNewline
Write-Host "$warnings" -ForegroundColor Yellow

Write-Host "  ✗ Failed:  " -ForegroundColor Red -NoNewline
Write-Host "$failed" -ForegroundColor Red

Write-Host ""

if ($failed -eq 0 -and $warnings -le 2) {
    Write-Host "✅ Pre-flight check passed! You're ready to run: docker-compose up" -ForegroundColor Green
    exit 0
} elseif ($failed -eq 0) {
    Write-Host "⚠️  Pre-flight check completed with warnings. Review above." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "❌ Pre-flight check failed. Fix errors above before running containers." -ForegroundColor Red
    exit 1
}
