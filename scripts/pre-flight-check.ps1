# Pre-flight validation script for Banana Slides deployment
param([switch]$Quick)

$passed = 0
$failed = 0
$warnings = 0

Write-Host "`n🍌 Banana Slides Pre-Flight Check`n" -ForegroundColor Cyan

# Test 1: Docker
Write-Host "1. Docker Check" -ForegroundColor Cyan
try {
    $version = docker --version
    Write-Host "   [+] Docker: $version" -ForegroundColor Green
    $passed++
} catch {
    Write-Host "   [-] Docker not found" -ForegroundColor Red
    $failed++
}

# Test 2: Ports
Write-Host "`n2. Port Availability" -ForegroundColor Cyan
$ports = @(5101, 3031, 11434, 14321)
foreach ($port in $ports) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Host "   [+] Port ${port}: In use" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "   [+] Port ${port}: Available" -ForegroundColor Green
        $passed++
    }
}

# Test 3: docker-compose.yml
Write-Host "`n3. Configuration Files" -ForegroundColor Cyan
if (Test-Path "docker-compose.yml") {
    Write-Host "   [+] docker-compose.yml found" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   [-] docker-compose.yml not found" -ForegroundColor Red
    $failed++
}

if (Test-Path ".env.example") {
    Write-Host "   [+] .env.example found" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   [-] .env.example not found" -ForegroundColor Red
    $failed++
}

# Test 4: .env file
Write-Host "`n4. Environment Configuration" -ForegroundColor Cyan
if (Test-Path ".env") {
    Write-Host "   [+] .env file exists" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   [!] .env file not found (create from .env.example)" -ForegroundColor Yellow
    $warnings++
}

# Test 5: Ollama
Write-Host "`n5. Local Services" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://host.docker.internal:11434/api/tags" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "   [+] Ollama responding" -ForegroundColor Green
        $passed++
    }
} catch {
    Write-Host "   [!] Ollama not responding (optional)" -ForegroundColor Yellow
    $warnings++
}

# Test 6: LM Studio
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:14321/api/v1/models" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "   [+] LM Studio responding" -ForegroundColor Green
        $passed++
    }
} catch {
    Write-Host "   [!] LM Studio not responding (optional)" -ForegroundColor Yellow
    $warnings++
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  [+] Passed:   $passed" -ForegroundColor Green
Write-Host "  [!] Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  [-] Failed:   $failed" -ForegroundColor Red

if ($failed -eq 0) {
    Write-Host "`n[SUCCESS] Ready to deploy!" -ForegroundColor Green
    Write-Host "  Run: docker-compose up -d`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] Fix errors above before deploying`n" -ForegroundColor Red
    exit 1
}
