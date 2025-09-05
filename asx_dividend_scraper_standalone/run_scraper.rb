#!/usr/bin/env ruby

# ASX Dividend Scraper Runner
# Simple standalone script to run the ASX dividend scraper

require 'bundler/setup'
require_relative 'lib/asx_dividend_scraper'

puts "ASX Dividend Scraper - Standalone Version"
puts "=========================================="
puts

begin
  scraper = AsxDividendScraper.new
  
  puts "Starting ASX dividend data scraping..."
  results = scraper.scrape_dividends
  
  if results && results.length > 0
    puts "Successfully scraped #{results.length} dividend records"
    
    # Save results to CSV
    require 'csv'
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = "output/asx_dividends_#{timestamp}.csv"
    
    CSV.open(filename, 'w') do |csv|
      # Write headers
      if results.first
        headers = results.first.is_a?(Hash) ? results.first.keys : []
        csv << headers if headers.any?
      end
      
      # Write data
      results.each do |row|
        if row.is_a?(Hash)
          csv << row.values
        end
      end
    end
    
    puts "Results saved to: #{filename}"
    
    # Display first few results
    puts "\nFirst 5 results:"
    results.first(5).each_with_index do |result, index|
      company = result['Entity name'] || result[:company] || 'N/A'
      code = result['Issuer'] || result[:code] || 'N/A'
      amount = result['Distribution Amount'] || result[:dividend_amount] || 'N/A'
      ex_date = result['Ex Date'] || result[:ex_date] || 'N/A'
      puts "#{index + 1}. #{company} (#{code}) - $#{amount} on #{ex_date}"
    end
    
    if results.length > 5
      puts "... and #{results.length - 5} more records"
    end
    
  else
    puts "No dividend data was scraped. Check debug files in debug_files/ directory."
  end
  
rescue => e
  puts "Error occurred during scraping:"
  puts e.message
  puts e.backtrace.first(5).join("\n")
  
  puts "\nCheck debug files in debug_files/ directory for more information."
end

puts "\nScraping completed."