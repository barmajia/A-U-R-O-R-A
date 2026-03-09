# Aurora E-commerce App - Test Runner Script
# PowerShell script for running tests

param(
    [Parameter(Position=0)]
    [string]$TestType = "",
    
    [Parameter(Position=1)]
    [string]$TestFile = ""
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Aurora E-commerce - Test Runner" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterPath = Get-Command flutter -ErrorAction Stop
} catch {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and try again." -ForegroundColor Red
    exit 1
}

Write-Host ""

switch ($TestType) {
    "" {
        Write-Host "Running all tests..." -ForegroundColor Green
        Write-Host ""
        flutter test
        break
    }
    
    "unit" {
        Write-Host "Running unit tests..." -ForegroundColor Green
        Write-Host ""
        flutter test test/unit/
        break
    }
    
    "widget" {
        Write-Host "Running widget tests..." -ForegroundColor Green
        Write-Host ""
        flutter test test/widget/
        break
    }
    
    "integration" {
        Write-Host "Running integration tests..." -ForegroundColor Green
        Write-Host ""
        flutter test test/integration/
        break
    }
    
    "coverage" {
        Write-Host "Running tests with coverage..." -ForegroundColor Green
        Write-Host ""
        flutter test --coverage
        Write-Host ""
        Write-Host "Generating HTML report..." -ForegroundColor Green
        
        if (Test-Path "coverage\lcov.info") {
            genhtml coverage\lcov.info -o coverage\html
            Write-Host ""
            Write-Host "Coverage report generated at: coverage\html\index.html" -ForegroundColor Green
            Start-Process "coverage\html\index.html"
        } else {
            Write-Host "ERROR: Coverage file not generated" -ForegroundColor Red
        }
        break
    }
    
    "file" {
        if ($TestFile -eq "") {
            Write-Host "ERROR: Please specify test file" -ForegroundColor Red
            Write-Host "Usage: .\test.ps1 file <test_file.dart>" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "Running test file: $TestFile" -ForegroundColor Green
        Write-Host ""
        flutter test $TestFile
        break
    }
    
    "watch" {
        Write-Host "Running tests in watch mode..." -ForegroundColor Green
        Write-Host ""
        flutter test --watch
        break
    }
    
    "name" {
        if ($TestFile -eq "") {
            Write-Host "ERROR: Please specify test name pattern" -ForegroundColor Red
            Write-Host "Usage: .\test.ps1 name <pattern>" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "Running tests matching: $TestFile" -ForegroundColor Green
        Write-Host ""
        flutter test --plain-name "$TestFile"
        break
    }
    
    default {
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Cyan
        Write-Host "  .\test.ps1                  - Run all tests" -ForegroundColor White
        Write-Host "  .\test.ps1 unit             - Run unit tests only" -ForegroundColor White
        Write-Host "  .\test.ps1 widget           - Run widget tests only" -ForegroundColor White
        Write-Host "  .\test.ps1 integration      - Run integration tests only" -ForegroundColor White
        Write-Host "  .\test.ps1 coverage         - Run tests with coverage report" -ForegroundColor White
        Write-Host "  .\test.ps1 watch            - Run tests in watch mode" -ForegroundColor White
        Write-Host "  .\test.ps1 file <file.dart> - Run specific test file" -ForegroundColor White
        Write-Host "  .\test.ps1 name <pattern>   - Run tests matching pattern" -ForegroundColor White
        Write-Host ""
        break
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Test Run Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
