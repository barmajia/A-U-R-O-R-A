# ================================================================
# AURORA E-COMMERCE - EDGE FUNCTIONS DEPLOYMENT SCRIPT
# ================================================================
# PowerShell script to deploy all Edge Functions to Supabase
# ================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Aurora E-commerce - Edge Functions   " -ForegroundColor Cyan
Write-Host "  Deployment Script                    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PROJECT_REF = "ofovfxsfazlwvcakpuer"  # Your Supabase project reference
$FUNCTIONS_DIR = "supabase\functions"

# Check if Supabase CLI is installed
Write-Host "Checking Supabase CLI installation..." -ForegroundColor Yellow
try {
    $supabaseVersion = supabase --version
    Write-Host "✓ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Supabase CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Supabase CLI:" -ForegroundColor Yellow
    Write-Host "  Windows: choco install supabase" -ForegroundColor Cyan
    Write-Host "  macOS:   brew install supabase/tap/supabase" -ForegroundColor Cyan
    Write-Host "  Linux:   curl -fsSL https://supabase.com/install.sh | bash" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host ""

# Check if logged in
Write-Host "Checking Supabase authentication..." -ForegroundColor Yellow
try {
    $supabaseStatus = supabase status 2>&1
    Write-Host "✓ Supabase CLI is configured" -ForegroundColor Green
} catch {
    Write-Host "✗ Not logged in to Supabase!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please login to Supabase:" -ForegroundColor Yellow
    Write-Host "  supabase login" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host ""

# Link project
Write-Host "Linking to Supabase project: $PROJECT_REF" -ForegroundColor Yellow
try {
    supabase link --project-ref $PROJECT_REF --password
    Write-Host "✓ Project linked successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to link project!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Set service role key (prompt user)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Service Role Key Configuration       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Please enter your Supabase Service Role Key:" -ForegroundColor Yellow
Write-Host "(Find it in: Dashboard → Settings → API → Service Role Key)" -ForegroundColor Gray
$serviceKey = Read-Host "Service Role Key"

if ($serviceKey) {
    Write-Host "Setting service role key secret..." -ForegroundColor Yellow
    try {
        supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceKey
        Write-Host "✓ Service role key configured" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set service role key!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Deploy functions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploying Edge Functions             " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @("create-product", "update-product", "delete-product", "search-products")
$deployedCount = 0
$failedCount = 0

foreach ($function in $functions) {
    Write-Host "Deploying: $function..." -ForegroundColor Yellow
    
    try {
        $result = supabase functions deploy $function --no-verify-jwt 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Deployed successfully!" -ForegroundColor Green
            $deployedCount++
        } else {
            Write-Host "  ✗ Deployment failed!" -ForegroundColor Red
            Write-Host "  Error: $result" -ForegroundColor Red
            $failedCount++
        }
    } catch {
        Write-Host "  ✗ Deployment failed!" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $failedCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary                   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Functions: $($functions.Count)" -ForegroundColor White
Write-Host "Deployed:        $deployedCount" -ForegroundColor Green
Write-Host "Failed:          $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failedCount -eq 0) {
    Write-Host "🎉 All functions deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Function URLs:" -ForegroundColor Cyan
    foreach ($function in $functions) {
        Write-Host "  https://$PROJECT_REF.supabase.co/functions/v1/$function" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "⚠️  Some functions failed to deploy." -ForegroundColor Yellow
    Write-Host "Check the error messages above and try again." -ForegroundColor Yellow
    Write-Host ""
}

# Push database schema
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Database Schema                      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Do you want to push the database schema now? (Y/N)" -ForegroundColor Yellow
$response = Read-Host

if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "Pushing database schema..." -ForegroundColor Yellow
    try {
        supabase db push
        Write-Host "✓ Database schema pushed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to push database schema!" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!                 " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the functions in your Flutter app" -ForegroundColor Gray
Write-Host "2. Monitor function logs in Supabase Dashboard" -ForegroundColor Gray
Write-Host "3. Set up monitoring and alerts" -ForegroundColor Gray
Write-Host ""
