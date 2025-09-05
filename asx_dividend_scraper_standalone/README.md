# ASX Dividend Scraper - Standalone Version

A standalone Ruby application that scrapes dividend announcements from the Australian Securities Exchange (ASX) website and exports the data to CSV format.

## Quick Start

### Windows Users
1. Install Ruby from https://rubyinstaller.org/ (Ruby+Devkit version)
2. Double-click `run_scraper.bat` 
3. Follow the prompts - the batch file will handle installation and running

### Mac/Linux Users
```bash
bundle install
ruby run_scraper.rb
```

## What It Does

- Scrapes current dividend announcements from ASX website
- Extracts company names, codes, dividend amounts, ex-dates, and payment dates
- Exports data to timestamped CSV files in the `output/` directory
- Saves debug information in `debug_files/` for troubleshooting

## Output

Results are saved as CSV files with the following columns:
- Company Name
- ASX Code
- Dividend Amount
- Ex-Dividend Date
- Payment Date
- Record Date
- Currency

## Files

- `run_scraper.rb` - Main runner script
- `run_scraper.bat` - Windows batch launcher
- `lib/asx_dividend_scraper.rb` - Core scraper logic
- `Gemfile` - Ruby dependencies
- `WINDOWS_INSTALL.md` - Detailed Windows installation guide
- `README_SCRAPER.md` - Technical documentation

## Requirements

- Ruby 3.1+
- Google Chrome browser
- Internet connection

## Installation

For detailed Windows installation instructions, see `WINDOWS_INSTALL.md`.

## Support

This is a standalone version extracted from the larger Futureproof application. For issues:

1. Check the debug files in `debug_files/` directory
2. Ensure Chrome browser is installed and up-to-date
3. Verify internet connectivity to asx.com.au
4. Review the installation guide for troubleshooting steps

## Legal

This tool scrapes publicly available information from the ASX website for personal use. Please respect the ASX website's terms of service and don't overuse this tool.