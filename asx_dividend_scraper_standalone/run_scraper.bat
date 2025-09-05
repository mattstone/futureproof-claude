@echo off
echo ASX Dividend Scraper - Windows Launcher
echo ==========================================
echo.

REM Change to the script directory
cd /d "%~dp0"

REM Check if Ruby is installed
ruby --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Ruby is not installed or not in PATH
    echo Please install Ruby from https://rubyinstaller.org/
    echo.
    pause
    exit /b 1
)

REM Check if Bundler is installed
bundler --version >nul 2>&1
if errorlevel 1 (
    echo Installing Bundler...
    gem install bundler
)

REM Install dependencies if needed
if not exist "Gemfile.lock" (
    echo Installing Ruby gems...
    bundle install
)

REM Create output directory if it doesn't exist
if not exist "output" mkdir output

REM Run the scraper
echo Running ASX Dividend Scraper...
echo.
ruby run_scraper.rb

REM Keep window open to see results
echo.
echo Press any key to close this window...
pause >nul