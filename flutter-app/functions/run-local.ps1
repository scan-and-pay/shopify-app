# PowerShell script to run Firebase Functions locally with environment variables
# Usage: .\run-local.ps1

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Firebase Functions Local Emulator" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env.local exists
if (-Not (Test-Path ".env.local")) {
    Write-Host "ERROR: .env.local file not found!" -ForegroundColor Red
    Write-Host "Please create .env.local from .env.local.example" -ForegroundColor Yellow
    Write-Host "  cp .env.local.example .env.local" -ForegroundColor Yellow
    exit 1
}

Write-Host "Loading environment variables from .env.local..." -ForegroundColor Green

# Read and set environment variables
Get-Content ".env.local" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Remove quotes if present
        $value = $value -replace '^["'']|["'']$', ''

        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        Write-Host "  ✓ $name" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
Write-Host ""

# Check if node_modules exists
if (-Not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
    Write-Host ""
}

Write-Host "Starting Firebase Emulators..." -ForegroundColor Cyan
Write-Host "  - Functions: http://localhost:5001" -ForegroundColor Gray
Write-Host "  - Firestore: http://localhost:8080" -ForegroundColor Gray
Write-Host "  - Emulator UI: http://localhost:4000" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Change to parent directory and start emulator
Set-Location ..
firebase emulators:start
