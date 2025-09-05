# ASX Dividend Scraper - Simple Windows Setup Guide

**This guide will help you set up the ASX dividend scraper on your Windows computer with easy step-by-step instructions.**

## What This Does

This program automatically downloads dividend information from the ASX website and saves it to your Dropbox folder at:
`C:\Users\samwi\Tavira Securities Dropbox\Sam Willis\Australia\DRP\dividends.csv`

---

## Step 1: Install WSL2 (Windows Subsystem for Linux)

### Why WSL2?
WSL2 is like having a small Linux computer inside your Windows computer. It makes the scraper much more reliable.

### Installation Steps:

1. **Open PowerShell as Administrator:**
   - Press `Windows key + X`
   - Click "Windows PowerShell (Admin)" or "Terminal (Admin)"
   - If prompted, click "Yes" to allow changes

2. **Install WSL2:**
   - Type this command and press Enter:
     ```
     wsl --install
     ```
   - Wait for it to finish (this may take 10-15 minutes)
   - **Restart your computer** when it asks you to

3. **Complete Ubuntu Setup:**
   - After restart, Ubuntu should open automatically
   - If not, search for "Ubuntu" in the Start menu and click it
   - Wait for "Installing..." to finish
   - Create a username (suggestion: use your first name, all lowercase)
   - Create a password (you won't see it typing, but it's working)
   - **Write down your username and password!**

---

## Step 2: Install Required Software

1. **In the Ubuntu window, copy and paste these commands one by one:**

   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
   (This updates the system - may take 5-10 minutes)

2. **Install Ruby and Chrome:**
   ```bash
   sudo apt install -y ruby-full build-essential git
   ```

3. **Install Google Chrome:**
   ```bash
   wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
   echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
   sudo apt update
   sudo apt install -y google-chrome-stable
   ```

4. **Verify everything is installed:**
   ```bash
   ruby --version
   google-chrome --version
   ```
   You should see version numbers for both.

---

## Step 3: Set Up the Scraper

1. **Create a folder for the scraper:**
   ```bash
   mkdir -p ~/asx_scraper
   cd ~/asx_scraper
   ```

2. **Copy the scraper files:**
   - Extract the `asx_dividend_scraper_standalone` folder to your Desktop
   - In Ubuntu, run:
   ```bash
   cp -r /mnt/c/Users/samwi/Desktop/asx_dividend_scraper_standalone/* .
   ```
   (Adjust the path if you put the files somewhere else)

3. **Install Ruby components:**
   ```bash
   gem install bundler
   bundle install
   ```

4. **Test the scraper:**
   ```bash
   ruby run_scraper.rb
   ```

---

## Step 4: What to Expect When Running

When you run the scraper, you'll see:

```
ASX Dividend Scraper - Standalone Version
==========================================

Starting ASX dividend data scraping...
Starting ASX Dividend Scraper...
Found 2 dividend/distribution announcements
Processing 2 dividend/distribution announcements
Processing announcement 1/2: Dividend/Distribution - ABC
Successfully processed: Dividend/Distribution - ABC
Processing announcement 2/2: Dividend/Distribution - XYZ
Successfully processed: Dividend/Distribution - XYZ
Successfully processed 2 dividend announcements
Data saved to: /mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/dividends.csv

First 5 results:
1. COMPANY NAME (ABC) - $0.05 on 15/09/2025
2. ANOTHER COMPANY (XYZ) - $0.12 on 18/09/2025

Scraping completed.
```

The CSV file will be automatically saved to your Dropbox folder!

---

## Step 5: Set Up Daily Automatic Running

### Option A: Simple Batch File (Recommended)

1. **Create a batch file on your Desktop:**
   - Right-click on Desktop → New → Text Document
   - Name it `Run ASX Scraper.txt`
   - Open it and paste:
   ```batch
   @echo off
   echo Running ASX Dividend Scraper...
   echo Please wait...
   wsl -d Ubuntu -e bash -c "cd ~/asx_scraper && ruby run_scraper.rb"
   echo.
   echo Done! Check your Dropbox folder for the results.
   echo Press any key to close this window...
   pause >nul
   ```
   - Save and close
   - Right-click the file → Rename → change extension from `.txt` to `.bat`

2. **To run the scraper:** Just double-click `Run ASX Scraper.bat`

### Option B: Windows Task Scheduler (For Daily Automation)

1. **Open Task Scheduler:**
   - Press `Windows key + R`
   - Type `taskschd.msc` and press Enter

2. **Create a new task:**
   - Click "Create Basic Task" on the right
   - Name: "ASX Dividend Scraper"
   - Description: "Daily dividend scraper"
   - Click "Next"

3. **Set when to run:**
   - Choose "Daily"
   - Click "Next"
   - Set time (suggest 9:00 AM)
   - Click "Next"

4. **Set what to run:**
   - Choose "Start a program"
   - Click "Next"
   - Program: `wsl`
   - Arguments: `-d Ubuntu -e bash -c "cd ~/asx_scraper && ruby run_scraper.rb"`
   - Click "Next", then "Finish"

---

## Troubleshooting

### If you see errors:

1. **"Ruby not found":**
   ```bash
   sudo apt install ruby-full
   ```

2. **"Chrome not found":**
   ```bash
   sudo apt install google-chrome-stable
   ```

3. **"Permission denied" for Dropbox folder:**
   - Make sure the Dropbox folder exists
   - In Windows File Explorer, create the folder if it doesn't exist:
   `C:\Users\samwi\Tavira Securities Dropbox\Sam Willis\Australia\DRP\`

4. **"No dividend announcements found":**
   - This is normal if there are no dividends announced today
   - The scraper only finds announcements for the current day

### Getting Help

If something doesn't work:

1. **Check the Dropbox folder** - the CSV file might still be there
2. **Try running again** - sometimes the ASX website is slow
3. **Look for error messages** - they usually explain what went wrong

### File Locations

- **Scraper program:** `~/asx_scraper/` (inside Ubuntu/WSL2)
- **CSV output:** `C:\Users\samwi\Tavira Securities Dropbox\Sam Willis\Australia\DRP\dividends.csv`
- **Backup CSV:** `~/asx_scraper/output/` (inside Ubuntu/WSL2)

---

## Daily Usage

### Manual (when you want to check for dividends):
1. Double-click `Run ASX Scraper.bat` on your Desktop
2. Wait for it to finish
3. Check your Dropbox folder for the updated `dividends.csv` file

### Automatic (set and forget):
- If you set up Task Scheduler, it will run automatically every day at 9 AM
- You'll find updated dividend information in your Dropbox folder
- The file is shared across all your devices through Dropbox

---

## What Files Are Created

The scraper creates/updates these files:
- **`dividends.csv`** - Main dividend data (in your Dropbox)
- **`output/asx_dividends_YYYYMMDD_HHMMSS.csv`** - Backup copy with timestamp

**The scraper automatically cleans up:**
- Downloaded PDF files (deleted after processing)
- Debug files (removed automatically)
- This keeps disk usage minimal

---

## Important Notes

- **Internet required:** The scraper needs internet to download from ASX
- **Runs quietly:** No windows will pop up when using Task Scheduler  
- **Safe to run:** Only reads public information from ASX website
- **Dropbox sync:** Files are immediately available on all your devices
- **Daily data:** Only shows dividends announced on the day it runs
- **Automatic cleanup:** No manual maintenance required

The scraper is designed to run reliably every day with no intervention required!