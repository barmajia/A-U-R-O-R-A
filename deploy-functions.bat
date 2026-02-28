@echo off
REM ==============================================================================
REM Supabase Edge Functions Deployment Script (Batch)
REM ==============================================================================
REM Usage: deploy-functions.bat
REM ==============================================================================

echo ========================================
echo   Supabase Edge Functions Deployment
echo ========================================
echo.

REM Check if Supabase CLI is installed
where supabase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Supabase CLI not found!
    echo.
    echo Install with:
    echo   winget install Supabase.CLI
    echo   OR
    echo   npm install -g supabase
    echo.
    pause
    exit /b 1
)

echo [OK] Supabase CLI found
echo.

REM Show version
supabase --version
echo.

echo ========================================
echo   Step 1: Authentication Check
echo ========================================
echo.

supabase auth status >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Not logged in to Supabase
    echo.
    echo Please login:
    echo   supabase login
    echo.
    set /p LOGIN="Open browser for login? (y/n): "
    if /i "%LOGIN%"=="y" (
        supabase login
    ) else (
        exit /b 1
    )
) else (
    echo [OK] Already authenticated
)

echo.
echo ========================================
echo   Step 2: Deploy Edge Functions
echo ========================================
echo.

set DEPLOYED=0
set FAILED=0

REM Deploy create-product
echo Deploying: create-product...
if exist "supabase\functions\create-product\index.ts" (
    supabase functions deploy create-product --no-verify-jwt
    if %ERRORLEVEL% EQU 0 (
        echo   [OK] Deployed successfully
        set /a DEPLOYED+=1
    ) else (
        echo   [ERROR] Deployment failed
        set /a FAILED+=1
    )
) else (
    echo   [ERROR] Function file not found
    set /a FAILED+=1
)
echo.

REM Deploy update-product
echo Deploying: update-product...
if exist "supabase\functions\update-product\index.ts" (
    supabase functions deploy update-product --no-verify-jwt
    if %ERRORLEVEL% EQU 0 (
        echo   [OK] Deployed successfully
        set /a DEPLOYED+=1
    ) else (
        echo   [ERROR] Deployment failed
        set /a FAILED+=1
    )
) else (
    echo   [ERROR] Function file not found
    set /a FAILED+=1
)
echo.

REM Deploy delete-product
echo Deploying: delete-product...
if exist "supabase\functions\delete-product\index.ts" (
    supabase functions deploy delete-product --no-verify-jwt
    if %ERRORLEVEL% EQU 0 (
        echo   [OK] Deployed successfully
        set /a DEPLOYED+=1
    ) else (
        echo   [ERROR] Deployment failed
        set /a FAILED+=1
    )
) else (
    echo   [ERROR] Function file not found
    set /a FAILED+=1
)
echo.

REM Deploy search-products
echo Deploying: search-products...
if exist "supabase\functions\search-products\index.ts" (
    supabase functions deploy search-products --no-verify-jwt
    if %ERRORLEVEL% EQU 0 (
        echo   [OK] Deployed successfully
        set /a DEPLOYED+=1
    ) else (
        echo   [ERROR] Deployment failed
        set /a FAILED+=1
    )
) else (
    echo   [ERROR] Function file not found
    set /a FAILED+=1
)
echo.

echo ========================================
echo   Step 3: Set Environment Secrets
echo ========================================
echo.
echo NOTE: You need to set SUPABASE_SERVICE_ROLE_KEY
echo.
set /p SETSECRET="Set SUPABASE_SERVICE_ROLE_KEY now? (y/n): "

if /i "%SETSECRET%"=="y" (
    echo.
    echo Get your service role key from:
    echo   https://app.supabase.com/project/_/settings/api
    echo.
    set /p SERVICEKEY="Enter SUPABASE_SERVICE_ROLE_KEY: "
    if defined SERVICEKEY (
        supabase secrets set SUPABASE_SERVICE_ROLE_KEY=%SERVICEKEY%
        echo [OK] Secret set successfully
    )
)

echo.
echo ========================================
echo   Deployment Summary
echo ========================================
echo.
echo Functions deployed: %DEPLOYED% / 4
echo Functions failed: %FAILED%
echo.

if %FAILED% EQU 0 (
    echo [OK] All functions deployed successfully!
    echo.
    echo Next steps:
    echo   1. Restart your Flutter app
    echo   2. Test creating a new product
    echo   3. Verify ASIN is generated server-side
) else (
    echo [ERROR] Some functions failed to deploy
    echo.
    echo Troubleshooting:
    echo   - Check your internet connection
    echo   - Verify project ref is correct
    echo   - Ensure you have write access
    echo   - Try: supabase functions deploy ^<name^> --no-verify-jwt
)

echo.
pause
