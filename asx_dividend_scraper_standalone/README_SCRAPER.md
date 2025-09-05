# ASX Dividend Scraper

A Ruby script to automatically download and process dividend/distribution announcements from the ASX website.

## Installation

1. Install required gems:
```bash
gem install mechanize pdf-reader nokogiri
```

Or using bundler with the provided Gemfile:
```bash
bundle install --gemfile=Gemfile.scraper
```

## Usage

Run the script:
```bash
ruby asx_dividend_scraper.rb
```

Or make it executable and run directly:
```bash
chmod +x asx_dividend_scraper.rb
./asx_dividend_scraper.rb
```

## What it does

1. **Navigates** to the ASX announcements page
2. **Accepts** terms and conditions if present
3. **Finds** all dividend/distribution announcements
4. **Downloads** PDFs (with rate limiting)
5. **Extracts** dividend data from PDF text
6. **Saves** results to `dividends.csv`

## Output

The script creates:
- `asx_dividends/` directory with downloaded PDFs
- `dividends.csv` with extracted dividend data

## CSV Headers

- Entity name
- Issuer  
- Security Description
- Date of this announcement
- Period End
- Distribution Amount
- Ex Date
- Record Date
- Payment Date
- DRP Election Date
- 3A.3 Percentage franked
- 4A.3 DRP discount rate
- Period of calculation of reinvestment price Start Date
- Period of calculation of reinvestment price End Date
- 4A.7 DRP securities issue date
- 4A.8 New issue?

## Features

- ✅ Automatic terms & conditions handling
- ✅ Rate limiting to avoid being blocked
- ✅ PDF download and text extraction
- ✅ Smart data extraction using regex patterns
- ✅ CSV output with proper headers
- ✅ Error handling and logging
- ✅ Development mode (processes 1 PDF first)

## Development

Currently set to process only the first dividend announcement found for testing. 
To process all announcements, modify the script to loop through all `dividend_links`.