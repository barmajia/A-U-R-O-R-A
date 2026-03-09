@echo off
REM Aurora E-commerce App - Test Runner Script
REM Windows batch script for running tests

echo ============================================
echo    Aurora E-commerce - Test Runner
echo ============================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter and try again.
    exit /b 1
)

REM Get command line argument
set TEST_TYPE=%1
set TEST_FILE=%2

echo.
if "%TEST_TYPE%"=="" (
    echo Running all tests...
    echo.
    flutter test
    goto :end
)

if "%TEST_TYPE%"=="unit" (
    echo Running unit tests...
    echo.
    flutter test test/unit/
    goto :end
)

if "%TEST_TYPE%"=="widget" (
    echo Running widget tests...
    echo.
    flutter test test/widget/
    goto :end
)

if "%TEST_TYPE%"=="integration" (
    echo Running integration tests...
    echo.
    flutter test test/integration/
    goto :end
)

if "%TEST_TYPE%"=="coverage" (
    echo Running tests with coverage...
    echo.
    flutter test --coverage
    echo.
    echo Generating HTML report...
    if exist "coverage\lcov.info" (
        genhtml coverage\lcov.info -o coverage\html
        echo.
        echo Coverage report generated at: coverage\html\index.html
        start coverage\html\index.html
    ) else (
        echo ERROR: Coverage file not generated
    )
    goto :end
)

if "%TEST_TYPE%"=="file" (
    if "%TEST_FILE%"=="" (
        echo ERROR: Please specify test file
        echo Usage: test.bat file ^<test_file.dart^>
        exit /b 1
    )
    echo Running test file: %TEST_FILE%
    echo.
    flutter test %TEST_FILE%
    goto :end
)

if "%TEST_TYPE%"=="watch" (
    echo Running tests in watch mode...
    echo.
    flutter test --watch
    goto :end
)

if "%TEST_TYPE%"=="name" (
    if "%TEST_FILE%"=="" (
        echo ERROR: Please specify test name pattern
        echo Usage: test.bat name ^<pattern^>
        exit /b 1
    )
    echo Running tests matching: %TEST_FILE%
    echo.
    flutter test --plain-name "%TEST_FILE%"
    goto :end
)

echo.
echo Usage:
echo   test.bat                  - Run all tests
echo   test.bat unit             - Run unit tests only
echo   test.bat widget           - Run widget tests only
echo   test.bat integration      - Run integration tests only
echo   test.bat coverage         - Run tests with coverage report
echo   test.bat watch            - Run tests in watch mode
echo   test.bat file ^<file.dart^>  - Run specific test file
echo   test.bat name ^<pattern^>    - Run tests matching pattern
echo.

:end
echo.
echo ============================================
echo    Test Run Complete
echo ============================================
