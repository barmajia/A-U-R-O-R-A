# Aurora E-commerce - Supabase Edge Functions Deployment Script
# Run this script to deploy all edge functions to your Supabase project

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AURORA - Supabase Functions Deploy  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectRef = "ofovfxsfazlwvcakpuer"
$functionsPath = "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora\supabase\functions"

# Check if Supabase CLI is installed
Write-Host "Checking Supabase CLI installation..." -ForegroundColor Yellow
try {
    $supabaseVersion = supabase --version 2>&1
    Write-Host "✓ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Supabase CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install it with: npm install -g supabase" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Check if logged in
Write-Host "Checking Supabase authentication..." -ForegroundColor Yellow
$loginCheck = supabase whoami 2>&1
if ($loginCheck -match "not logged in") {
    Write-Host "✗ Not logged in to Supabase!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please login with: supabase login" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✓ Logged in as: $loginCheck" -ForegroundColor Green
}

Write-Host ""

# Navigate to functions directory
Write-Host "Navigating to functions directory..." -ForegroundColor Yellow
Set-Location $functionsPath
Write-Host "✓ Current directory: $(Get-Location)" -ForegroundColor Green

Write-Host ""

# Deploy process-signup
Write-Host "Deploying process-signup function..." -ForegroundColor Yellow
supabase functions deploy process-signup --project-ref $projectRef
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ process-signup deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to deploy process-signup" -ForegroundColor Red
}

Write-Host ""

# Deploy process-login
Write-Host "Deploying process-login function..." -ForegroundColor Yellow
supabase functions deploy process-login --project-ref $projectRef
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ process-login deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to deploy process-login" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!                 " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://supabase.com/dashboard/project/$projectRef" -ForegroundColor White
Write-Host "2. Navigate to Edge Functions to verify deployment" -ForegroundColor White
Write-Host "3. Test signup/login in your Flutter app" -ForegroundColor White
Write-Host "4. Check Logs to see function executions" -ForegroundColor White
Write-Host ""
