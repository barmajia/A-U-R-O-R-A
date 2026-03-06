# ============================================================================
# Aurora Edge Functions - Complete Deployment Script
# ============================================================================
# Description: Deploys all Edge Functions to Supabase
# Usage: .\deploy-all-functions.ps1
# ============================================================================

Write-Host "🚀 Aurora Edge Functions Deployment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PROJECT_REF = "ofovfxsfazlwvcakpuer"
$FUNCTIONS_DIR = "supabase\functions"

# List of all functions to deploy
$FUNCTIONS = @(
    "create-product",
    "update-product", 
    "delete-product",
    "search-products",
    "find-nearby-factories",
    "request-factory-connection",
    "rate-factory",
    "manage-product",
    "create-order",
    "upload-image",
    "delete-image",
    "get-image-url",
    "process-signup",
    "process-login"
)

# Check if Supabase CLI is installed
Write-Host "📦 Checking Supabase CLI..." -ForegroundColor Yellow
$supabaseVersion = supabase --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Supabase CLI not found. Install it first:" -ForegroundColor Red
    Write-Host "   npm install -g supabase" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Found: $supabaseVersion" -ForegroundColor Green
Write-Host ""

# Check if logged in
Write-Host "🔐 Checking authentication..." -ForegroundColor Yellow
$loginStatus = supabase projects list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in. Please run:" -ForegroundColor Red
    Write-Host "   supabase login" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Authenticated" -ForegroundColor Green
Write-Host ""

# Link project
Write-Host "🔗 Linking to project: $PROJECT_REF" -ForegroundColor Yellow
supabase link --project-ref $PROJECT_REF
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Could not link project. Continuing anyway..." -ForegroundColor Yellow
}
Write-Host ""

# Deploy all functions
$successCount = 0
$failCount = 0

Write-Host "🚀 Deploying $($FUNCTIONS.Count) Edge Functions..." -ForegroundColor Cyan
Write-Host ""

foreach ($function in $FUNCTIONS) {
    Write-Host "📦 Deploying: $function" -ForegroundColor Yellow
    
    # Deploy with --no-verify-jwt for most functions (they handle auth internally)
    $deployOutput = supabase functions deploy $function --no-verify-jwt 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Success" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "   ❌ Failed: $deployOutput" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "📊 Deployment Summary" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "✅ Successful: $successCount / $($FUNCTIONS.Count)" -ForegroundColor Green
Write-Host "❌ Failed: $failCount / $($FUNCTIONS.Count)" -ForegroundColor Red
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "🎉 All functions deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some functions failed. Check errors above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Set Service Role Key in Supabase Dashboard" -ForegroundColor White
Write-Host "   https://app.supabase.com/project/$PROJECT_REF/settings/api" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test functions in your Flutter app" -ForegroundColor White
Write-Host ""
Write-Host "3. Monitor logs:" -ForegroundColor White
Write-Host "   supabase functions logs --function <function-name>" -ForegroundColor Gray
Write-Host ""
