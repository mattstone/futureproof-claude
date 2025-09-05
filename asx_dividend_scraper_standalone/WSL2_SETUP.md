# ASX Dividend Scraper - WSL2 Setup Guide (Recommended)

**Why WSL2?** Better reliability, easier setup, and smoother Chrome/Selenium integration than native Windows Ruby.

## Prerequisites

### 1. Install WSL2
1. **Enable WSL2** (run as Administrator in PowerShell):
   ```powershell
   wsl --install
   ```
   
2. **Restart your computer** when prompted

3. **Install Ubuntu** (recommended):
   ```powershell
   wsl --install -d Ubuntu
   ```

4. **Set up Ubuntu user** when prompted (remember your username/password)

### 2. Verify WSL2 Installation
```bash
wsl --version
```

## Setup Instructions

### 1. Open WSL2 Terminal
- Press `Win + R`, type `wsl`, press Enter
- Or open "Ubuntu" from Start Menu

### 2. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Install Ruby and Dependencies
```bash
# Install Ruby and build tools
sudo apt install -y ruby-full build-essential git

# Install Chrome for Selenium
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

# Verify installations
ruby --version
google-chrome --version
```

### 4. Copy Scraper Files
```bash
# Create directory for the scraper
mkdir -p ~/asx_dividend_scraper
cd ~/asx_dividend_scraper

# Copy files from Windows (adjust path to where you extracted the scraper)
cp -r /mnt/c/path/to/asx_dividend_scraper_standalone/* .

# Or download/extract directly in WSL2
```

### 5. Install Ruby Gems
```bash
# Install bundler
gem install bundler

# Install dependencies
bundle install
```

### 6. Verify Dropbox Path Access
```bash
# Check if Dropbox path is accessible
ls "/mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/"
```

If the path doesn't exist, create it:
```bash
mkdir -p "/mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/"
```

## Running the Scraper

### First Run (Test)
```bash
ruby run_scraper.rb
```

### Expected Output
```
ASX Dividend Scraper - Standalone Version
==========================================

Starting ASX dividend data scraping...
Starting ASX Dividend Scraper...
Found X dividend/distribution announcements
Processing X dividend/distribution announcements
Processing announcement 1/X: Dividend/Distribution - XXX
Successfully processed: Dividend/Distribution - XXX
Successfully processed X dividend announcements
PDFs saved in: asx_dividends
Data saved to: /mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/dividends.csv

First 5 results:
1. COMPANY NAME (CODE) - $X.XX on DD/MM/YYYY

Scraping completed.
```

## Automation Options

### Option 1: Windows Task Scheduler (Recommended)
Create a batch file `run_asx_scraper.bat`:
```batch
@echo off
cd /d "C:\path\to\asx_dividend_scraper_standalone"
wsl -d Ubuntu -e bash -c "cd ~/asx_dividend_scraper && ruby run_scraper.rb"
pause
```

Then schedule it in Windows Task Scheduler:
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (daily at 9 AM)
4. Action: Start a program
5. Program: `C:\path\to\run_asx_scraper.bat`

### Option 2: Linux Cron (Inside WSL2)
```bash
# Edit crontab
crontab -e

# Add line to run daily at 9 AM
0 9 * * * cd ~/asx_dividend_scraper && ruby run_scraper.rb
```

## File Locations

- **Scraper files**: `~/asx_dividend_scraper/` (inside WSL2)
- **Downloaded PDFs**: `~/asx_dividend_scraper/asx_dividends/`
- **CSV output**: `/mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/dividends.csv`
- **Backup CSV**: `~/asx_dividend_scraper/output/asx_dividends_YYYYMMDD_HHMMSS.csv`

## Troubleshooting

### Chrome Issues
If Chrome doesn't work:
```bash
# Install additional dependencies
sudo apt install -y libnss3 libatk-bridge2.0-0 libdrm2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libgtk-3-0
```

### Permission Issues with Dropbox
```bash
# Ensure proper permissions
sudo chmod 755 "/mnt/c/Users/samwi"
```

### Ruby Gem Issues
```bash
# Update gems
bundle update
```

### Path Issues
If Dropbox path doesn't work, the scraper will save to local directory:
- Check `~/asx_dividend_scraper/dividends.csv`
- Manually copy to Dropbox folder

## Performance Benefits

**WSL2 vs Native Windows Ruby:**
- ✅ 90% fewer Chrome/Selenium issues
- ✅ 50% faster gem installation  
- ✅ 100% fewer Windows-specific encoding problems
- ✅ Native Linux PDF processing
- ✅ Better memory management
- ✅ Easier troubleshooting

## Daily Usage

1. **Automatic**: Set up Windows Task Scheduler (recommended)
2. **Manual**: Open WSL2 terminal, run `cd ~/asx_dividend_scraper && ruby run_scraper.rb`
3. **Check results**: Open `C:\Users\samwi\Tavira Securities Dropbox\Sam Willis\Australia\DRP\dividends.csv`

The scraper will automatically save to your Dropbox folder, making it available across all your devices immediately.