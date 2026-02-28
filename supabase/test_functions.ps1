# Test Supabase Edge Functions After Deployment
# Run this after deploying to verify functions work

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing Edge Functions               " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectRef = "ofovfxsfazlwvcakpuer"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mb3ZmeHNmYXpsd3ZjYWtwdWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjY0MDcsImV4cCI6MjA4NzcwMjQwN30.QYx8-c9IiSMpuHeikKz25MKO5o6g112AKj4Tnr4aWzI"
$baseUrl = "https://$projectRef.supabase.co/functions/v1"

Write-Host "Testing process-signup function..." -ForegroundColor Yellow
Write-Host ""

$signupData = @{
    userId = "test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    email = "test@example.com"
    fullName = "Test User"
    accountType = "seller"
    phone = "+1234567890"
    location = "Test City"
    currency = "USD"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/process-signup" -Method Post -Body $signupData -ContentType "application/json"
    Write-Host "✓ Response: $($response.message)" -ForegroundColor Green
    Write-Host "  Success: $($response.success)" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Complete                        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
