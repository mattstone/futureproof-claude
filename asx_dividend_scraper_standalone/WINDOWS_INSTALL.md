# ASX Dividend Scraper - Windows Installation Guide

This is a standalone Ruby application that scrapes dividend information from the ASX (Australian Securities Exchange) website.

## Prerequisites

### 1. Install Ruby on Windows

**Option A: Using RubyInstaller (Recommended)**
1. Go to https://rubyinstaller.org/downloads/
2. Download Ruby+Devkit 3.1 or later (e.g., Ruby+Devkit 3.1.4-1 (x64))
3. Run the installer as Administrator
4. During installation:
   - Check "Add Ruby executables to your PATH"
   - Check "Associate .rb and .rbw files with this Ruby installation"
   - Complete the installation
5. When prompted, run `ridk install` and choose option 3 (MSYS2 and MINGW development toolchain)

**Option B: Using Windows Subsystem for Linux (WSL)**
1. Install WSL2 from Microsoft Store
2. Install Ubuntu or Debian
3. Open WSL terminal and install Ruby:
   ```bash
   sudo apt update
   sudo apt install ruby-full
   ```

### 2. Verify Ruby Installation

Open Command Prompt or PowerShell and run:
```cmd
ruby --version
gem --version
```

You should see Ruby version 3.1+ and gem version output.

## Installation Steps

### 1. Download and Extract
1. Download this `asx_dividend_scraper_standalone` folder to your computer
2. Place it in a location like `C:\Tools\asx_dividend_scraper_standalone\`
3. Open Command Prompt as Administrator

### 2. Navigate to Directory
```cmd
cd C:\Tools\asx_dividend_scraper_standalone
```

### 3. Install Dependencies
```cmd
gem install bundler
bundle install
```

This will install the required gems:
- selenium-webdriver (for browser automation)
- nokogiri (for HTML parsing)
- csv (for data export)

### 4. Install Chrome Browser
The scraper uses Chrome browser, so ensure you have Google Chrome installed:
1. Download from https://www.google.com/chrome/
2. Install normally

The scraper will automatically download the appropriate ChromeDriver.

## Running the Scraper

### Basic Usage
```cmd
ruby run_scraper.rb
```

### What it does:
1. Opens Chrome browser (headless mode)
2. Navigates to ASX dividend announcements page
3. Scrapes current dividend data
4. Saves results to CSV file in `output/` folder
5. Displays summary of scraped data

### Output Files
- **CSV files**: `output/asx_dividends_YYYYMMDD_HHMMSS.csv`
- **Debug files**: `debug_files/` (HTML snapshots for troubleshooting)

## Troubleshooting

### Common Issues

**1. "bundler: command not found"**
```cmd
gem install bundler
```

**2. "Permission denied" errors**
- Run Command Prompt as Administrator
- Or install to user directory: `gem install --user-install bundler`

**3. Chrome/ChromeDriver issues**
- Ensure Google Chrome is installed
- The scraper auto-downloads ChromeDriver
- If issues persist, manually install ChromeDriver from https://chromedriver.chromium.org/

**4. SSL Certificate errors**
```cmd
gem update --system
```

**5. Firewall/Antivirus blocking**
- Add exception for Ruby and Chrome processes
- Temporarily disable antivirus to test

**6. Network connectivity issues**
- Check internet connection
- Verify you can access https://www.asx.com.au/ in browser
- Check corporate firewall settings

### Debug Information

If scraping fails:
1. Check `debug_files/` folder for HTML snapshots
2. Look for error messages in console output
3. Verify Chrome browser opens correctly

### Manual Testing

To test individual components:

**Test Ruby installation:**
```cmd
ruby -e "puts 'Ruby is working!'"
```

**Test gem installation:**
```cmd
ruby -e "require 'selenium-webdriver'; puts 'Selenium gem loaded'"
ruby -e "require 'nokogiri'; puts 'Nokogiri gem loaded'"
```

**Test Chrome automation:**
```cmd
ruby -e "
require 'selenium-webdriver'
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
driver = Selenium::WebDriver.for :chrome, options: options
driver.get 'https://www.google.com'
puts 'Chrome automation working: ' + driver.title
driver.quit
"
```

## Configuration

### Changing Output Directory
Edit `run_scraper.rb` and modify the `filename` line:
```ruby
filename = "C:/your/custom/path/asx_dividends_#{timestamp}.csv"
```

### Adjusting Scraper Settings
Edit `lib/asx_dividend_scraper.rb` to modify:
- Browser settings (headless mode, window size, etc.)
- Wait times and timeouts
- Debug output options

## Scheduling (Optional)

### Windows Task Scheduler
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (daily, weekly, etc.)
4. Set action: Start a program
5. Program: `ruby`
6. Arguments: `C:\Tools\asx_dividend_scraper_standalone\run_scraper.rb`
7. Start in: `C:\Tools\asx_dividend_scraper_standalone`

### Command Line Scheduling
```cmd
# Run daily at 9 AM
schtasks /create /tn "ASX Dividend Scraper" /tr "ruby C:\Tools\asx_dividend_scraper_standalone\run_scraper.rb" /sc daily /st 09:00
```

## Files Structure

```
asx_dividend_scraper_standalone/
├── WINDOWS_INSTALL.md          # This installation guide
├── README_SCRAPER.md           # Original technical documentation
├── Gemfile                     # Ruby dependencies
├── run_scraper.rb              # Main runner script
├── lib/
│   └── asx_dividend_scraper.rb # Core scraper logic
├── debug_files/                # HTML debug snapshots
│   ├── asx_page_debug.html
│   ├── asx_iframe_2_debug.html
│   └── asx_dividends/
├── output/                     # CSV output files (created when run)
└── Gemfile.lock               # Locked dependency versions (created by bundler)
```

## Support

For issues specific to:
- **Ruby installation**: Check https://rubyinstaller.org/
- **Windows compatibility**: Ensure you're using Ruby+Devkit version
- **Browser automation**: Verify Chrome is installed and up-to-date
- **Network issues**: Check firewall and proxy settings

## Security Notes

- The scraper only reads public information from ASX website
- No personal data is collected or stored
- All network requests are to official ASX domains
- Debug files contain only HTML snapshots (no sensitive data)

## Performance

- Typical run time: 30-60 seconds
- Memory usage: ~100-200 MB during execution
- Network usage: ~5-10 MB per run
- Disk space: ~1-5 MB per CSV output file