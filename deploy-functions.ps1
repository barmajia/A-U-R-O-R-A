#!/usr/bin/env pwsh
# ==============================================================================
# Supabase Edge Functions Deployment Script
# ==============================================================================
# This script deploys all product-related Edge Functions to Supabase.
#
# Prerequisites:
# 1. Install Supabase CLI: https://supabase.com/docs/guides/cli
# 2. Login: supabase login
# 3. Link project: supabase link --project-ref YOUR_PROJECT_REF
#
# Usage: .\deploy-functions.ps1
# ==============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Supabase Edge Functions Deployment  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
Write-Host "Checking Supabase CLI installation..." -ForegroundColor Yellow
try {
    $supabaseVersion = supabase --version 2>&1
    Write-Host "✓ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Supabase CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  winget install Supabase.CLI" -ForegroundColor White
    Write-Host "  OR" -ForegroundColor Yellow
    Write-Host "  npm install -g supabase" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 1: Check Authentication        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if logged in
Write-Host "Checking authentication status..." -ForegroundColor Yellow
$authStatus = supabase auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Not logged in to Supabase" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please login with:" -ForegroundColor Yellow
    Write-Host "  supabase login" -ForegroundColor White
    Write-Host ""
    Write-Host "This will open a browser for authentication." -ForegroundColor Gray
    $login = Read-Host "Open browser for login? (y/n)"
    if ($login -eq 'y' -or $login -eq 'Y') {
        supabase login
    } else {
        exit 1
    }
} else {
    Write-Host "✓ Already authenticated" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 2: Link Project                " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if project is linked
Write-Host "Checking project linkage..." -ForegroundColor Yellow
$projectLink = Get-Content .supabase\project-ref 2>$null
if ($null -eq $projectLink) {
    Write-Host "✗ Project not linked" -ForegroundColor Red
    Write-Host ""
    Write-Host "Your project ref is the last part of your Supabase URL:" -ForegroundColor Gray
    Write-Host "  https://abcdefghijk.supabase.co  →  ref = 'abcdefghijk'" -ForegroundColor Gray
    Write-Host ""
    $projectRef = Read-Host "Enter your project ref"
    if ($projectRef) {
        supabase link --project-ref $projectRef
    } else {
        exit 1
    }
} else {
    Write-Host "✓ Project linked: $projectLink" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 3: Deploy Edge Functions       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# List of functions to deploy
$functions = @(
    "create-product",
    "update-product",
    "delete-product",
    "search-products"
)

$deployedCount = 0
$failedCount = 0

foreach ($function in $functions) {
    Write-Host "Deploying: $function..." -ForegroundColor Yellow
    
    # Check if function exists
    $functionPath = "supabase\functions\$function\index.ts"
    if (-not (Test-Path $functionPath)) {
        Write-Host "  ✗ Function file not found: $functionPath" -ForegroundColor Red
        $failedCount++
        continue
    }
    
    # Deploy function
    $deployOutput = supabase functions deploy $function --no-verify-jwt 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Deployed successfully" -ForegroundColor Green
        $deployedCount++
    } else {
        Write-Host "  ✗ Deployment failed" -ForegroundColor Red
        Write-Host "  Output: $deployOutput" -ForegroundColor Gray
        $failedCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 4: Set Environment Secrets     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Setting up environment secrets..." -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: You need to set your SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Yellow
Write-Host ""
$setSecret = Read-Host "Set SUPABASE_SERVICE_ROLE_KEY now? (y/n)"

if ($setSecret -eq 'y' -or $setSecret -eq 'Y') {
    Write-Host ""
    Write-Host "Get your service role key from:" -ForegroundColor Gray
    Write-Host "  https://app.supabase.com/project/_/settings/api" -ForegroundColor Cyan
    Write-Host ""
    $serviceKey = Read-Host "Enter SUPABASE_SERVICE_ROLE_KEY"
    
    if ($serviceKey) {
        supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceKey
        Write-Host "✓ Secret set successfully" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary                  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Functions deployed: $deployedCount / $($functions.Count)" -ForegroundColor Green
Write-Host "Functions failed: $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failedCount -eq 0) {
    Write-Host "✓ All functions deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Restart your Flutter app" -ForegroundColor White
    Write-Host "  2. Test creating a new product" -ForegroundColor White
    Write-Host "  3. Verify ASIN is generated server-side" -ForegroundColor White
} else {
    Write-Host "✗ Some functions failed to deploy" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Check your internet connection" -ForegroundColor White
    Write-Host "  - Verify project ref is correct" -ForegroundColor White
    Write-Host "  - Ensure you have write access to the project" -ForegroundColor White
    Write-Host "  - Try running: supabase functions deploy <function-name> --no-verify-jwt" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
