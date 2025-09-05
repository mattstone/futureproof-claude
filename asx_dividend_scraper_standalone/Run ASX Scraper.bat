@echo off
title ASX Dividend Scraper
color 0A
echo.
echo ===============================================
echo          ASX Dividend Scraper
echo ===============================================
echo.
echo Starting dividend scraper...
echo Please wait while we check for new dividends...
echo.

REM Run the scraper in WSL2
wsl -d Ubuntu -e bash -c "cd ~/asx_scraper && ruby run_scraper.rb"

echo.
echo ===============================================
echo              COMPLETED
echo ===============================================
echo.
echo The scraper has finished running.
echo Check your Dropbox folder for the results:
echo C:\Users\samwi\Tavira Securities Dropbox\Sam Willis\Australia\DRP\dividends.csv
echo.
echo Press any key to close this window...
pause >nul