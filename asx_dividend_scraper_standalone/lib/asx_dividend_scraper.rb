#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'pdf-reader'
require 'uri'
require 'net/http'
require 'fileutils'
require 'selenium-webdriver'
require 'nokogiri'

class AsxDividendScraper
  BASE_URL = 'https://www.asx.com.au/markets/trade-our-cash-market/todays-announcements'
  
  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.request_headers = {
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.5',
      'Accept-Encoding' => 'gzip, deflate, br',
      'Connection' => 'keep-alive',
      'Upgrade-Insecure-Requests' => '1'
    }
    
    @downloads_dir = 'asx_dividends'
    FileUtils.mkdir_p(@downloads_dir)
    
    @csv_headers = [
      'Entity name',
      'Issuer', 
      'Security Description',
      'Date of this announcement',
      'Period End',
      'Distribution Amount',
      'Ex Date',
      'Record Date', 
      'Payment Date',
      'DRP Election Date',
      '3A.3 Percentage franked',
      '4A.3 DRP discount rate',
      'Period of calculation of reinvestment price Start Date',
      'Period of calculation of reinvestment price End Date',
      '4A.7 DRP securities issue date',
      '4A.8 New issue?'
    ]
  end

  def scrape_dividends
    result = scrape_and_process
    return result
  end

  def scrape_and_process
    puts "Starting ASX Dividend Scraper..."
    
    # Try Selenium approach first (to handle JavaScript)
    dividend_links = find_dividend_announcements_via_selenium
    
    if dividend_links.empty?
      # Try API approach
      dividend_links = find_dividend_announcements_via_api
      
      if dividend_links.empty?
        # Navigate to the ASX announcements page
        page = @agent.get(BASE_URL)
        
        # Check for and handle terms & conditions
        handle_terms_and_conditions(page)
        
        # Find dividend/distribution announcements
        dividend_links = find_dividend_announcements(page)
      end
    end
    
    if dividend_links.empty?
      # Look for saved iframe content from Selenium
      iframe_files = Dir.glob("asx_iframe_*_debug.html")
      iframe_files.each do |iframe_file|
        if File.exist?(iframe_file)
          iframe_content = File.read(iframe_file)
          
          # Look for dividend/distribution links in iframe content
          require 'nokogiri'
          doc = Nokogiri::HTML(iframe_content)
          
          # Search for links containing dividend/distribution (not updates)
          found_links = []
          doc.search('a').each do |link|
            link_text = link.text.to_s.strip
            href = link['href']
            
            # Only process "Dividend/Distribution" announcements, not updates
            if href && link_text.match?(/^Dividend\/Distribution\s*-/i) && href.include?('displayAnnouncement')
              found_links << {
                title: link_text,
                href: href,
                full_url: href.start_with?('http') ? href : "https://www.asx.com.au#{href}"
              }
            end
          end
          
          if found_links.any?
            puts "Found #{found_links.length} dividend/distribution announcements"
            dividend_links.concat(found_links)
          end
          
          # Clean up debug file
          File.delete(iframe_file)
        end
      end
    end
    
    puts "Processing #{dividend_links.length} dividend/distribution announcements"
    
    if dividend_links.empty?
      puts "No dividend announcements found to process"
      return []
    end
    
    # Process all dividend announcements found
    all_extracted_data = []
    successful_downloads = 0
    
    dividend_links.each_with_index do |link, index|
      puts "Processing announcement #{index + 1}/#{dividend_links.length}: #{link[:title]}"
      
      # Download and process PDF
      pdf_path = download_pdf(link)
      
      if pdf_path
        # Extract data from PDF
        extracted_data = extract_pdf_data(pdf_path)
        all_extracted_data << extracted_data
        successful_downloads += 1
        
        puts "Successfully processed: #{link[:title]}"
        
        # Clean up PDF file to save disk space
        File.delete(pdf_path) if File.exist?(pdf_path)
      else
        puts "Failed to download PDF for: #{link[:title]}"
      end
      
      # Add a small delay between downloads to be respectful
      sleep(2) if index < dividend_links.length - 1
    end
    
    # Save all data to CSV
    if all_extracted_data.any?
      save_to_csv(all_extracted_data)
      puts "Successfully processed #{successful_downloads} dividend announcements"
    else
      puts "No data to save to CSV"
    end
    
    # Clean up any remaining debug files
    cleanup_debug_files
    
    # Return the extracted data so the caller can use it
    all_extracted_data
  end

  def find_dividend_announcements_via_selenium
    dividend_links = []
    
    begin
      # Set up Chrome options for headless browsing
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1920,1080')
      options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36')
      
      driver = Selenium::WebDriver.for :chrome, options: options
      driver.get(BASE_URL)
      sleep(3)
      
      # Handle cookie consent prompt
      begin
        cookie_button = driver.find_element(:id, 'onetrust-accept-btn-handler')
        cookie_button.click
        sleep(2)
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # No cookie consent prompt found
      end
      
      sleep(5)  # Wait for JavaScript content to load
      
      # Wait for content to load
      wait = Selenium::WebDriver::Wait.new(timeout: 30)
      
      # Look for loading indicators and wait for them to disappear
      begin
        loading_elements = driver.find_elements(:css, '.loading, .spinner, [data-loading], .announcement-loading')
        if loading_elements.any?
          wait.until { driver.find_elements(:css, '.loading, .spinner, [data-loading], .announcement-loading').none? { |el| el.displayed? } }
        end
      rescue Selenium::WebDriver::Error::TimeoutError
        # Continue if timeout
      end
      
      sleep(10)  # Additional wait for announcements to load
      
      # Try to find announcement content
      announcement_indicators = [
        'table tbody tr',
        '.announcement',
        '.announcement-row',
        '[data-announcement]',
        '.market-announcements'
      ]
      
      found_content = false
      announcement_indicators.each do |selector|
        elements = driver.find_elements(:css, selector)
        if elements.any?
          found_content = true
          break
        end
      end
      
      unless found_content
        # Try scrolling down to trigger lazy loading
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        sleep(3)
        
        # Check for iframes that might contain the announcements
        iframes = driver.find_elements(:tag_name, 'iframe')
        
        iframes.each_with_index do |iframe, i|
          begin
            driver.switch_to.frame(iframe)
            sleep(2)
            iframe_source = driver.page_source
            
            if iframe_source.downcase.include?('announcement') || iframe_source.downcase.include?('dividend')
              # Save the iframe content temporarily for processing
              File.write("asx_iframe_#{i + 1}_debug.html", iframe_source)
              found_content = true
              page_source = iframe_source
              driver.switch_to.default_content
              break
            end
            
            driver.switch_to.default_content
          rescue => e
            driver.switch_to.default_content
          end
        end
      end
      
      # Get the page source after JavaScript execution
      page_source = driver.page_source unless defined?(page_source)
      
      # Parse with Nokogiri
      doc = Nokogiri::HTML(page_source)
      
      # Look for "Dividend/Distribution" announcements (not updates)
      dividend_links_found = doc.search('//a[contains(@href, "displayAnnouncement.do")]')
      
      dividend_links_found.each do |link|
        link_text = link.text.to_s.strip
        # Only process "Dividend/Distribution" announcements, not dividend updates
        if link_text.match?(/^Dividend\/Distribution\s*-/i)
          href = link['href']
          if href
            dividend_links << {
              title: link_text,
              href: href,
              full_url: href.start_with?('http') ? href : "https://www.asx.com.au#{href}"
            }
          end
        end
      end
      
    rescue => e
      # Handle Selenium errors silently
    ensure
      driver&.quit
    end
    
    dividend_links.uniq { |link| link[:href] }
  end

  def find_dividend_announcements_via_api
    dividend_links = []
    
    # Try different API endpoints
    api_urls = [
      'https://asx.api.markitdigital.com/asx-research/1.0/announcements',
      'https://asx.api.markitdigital.com/asx-research/1.0/announcements/today',
      'https://www.asx.com.au/bin/asx/beta/servlets/announcements'
    ]
    
    api_urls.each do |api_url|
      begin
        @agent.request_headers['Accept'] = 'application/json, text/plain, */*'
        @agent.request_headers['Referer'] = BASE_URL
        
        response = @agent.get(api_url)
        
        if response.body.include?('dividend') || response.body.include?('distribution')
          # Try to parse as JSON
          begin
            require 'json'
            data = JSON.parse(response.body)
            
            # Look for dividend/distribution entries
            if data.is_a?(Array)
              data.each do |item|
                if item.is_a?(Hash) && 
                   (item.to_s.downcase.include?('dividend/distribution'))
                  # Extract PDF URL if available
                  pdf_url = item['pdfUrl'] || item['url'] || item['link']
                  if pdf_url
                    dividend_links << {
                      title: item['heading'] || item['title'] || 'Dividend/Distribution',
                      href: pdf_url,
                      full_url: pdf_url.start_with?('http') ? pdf_url : "https://www.asx.com.au#{pdf_url}"
                    }
                  end
                end
              end
            end
          rescue JSON::ParserError
            # Continue if not JSON
          end
        end
        
      rescue => e
        # Continue if API request fails
      end
    end
    
    dividend_links
  end

  private

  def handle_terms_and_conditions(page)
    # Look for common terms & conditions patterns
    terms_form = page.forms.find { |f| 
      f.to_s.downcase.include?('terms') || 
      f.to_s.downcase.include?('conditions') ||
      f.to_s.downcase.include?('accept')
    }
    
    if terms_form
      # Find accept button/checkbox
      accept_button = terms_form.buttons.find { |b| 
        b.value.to_s.downcase.include?('accept') || 
        b.value.to_s.downcase.include?('agree') 
      }
      
      accept_checkbox = terms_form.checkboxes.find { |c|
        c.name.to_s.downcase.include?('accept') ||
        c.name.to_s.downcase.include?('agree') ||
        c.name.to_s.downcase.include?('terms')
      }
      
      if accept_checkbox
        accept_checkbox.check
      end
      
      if accept_button
        page = @agent.submit(terms_form, accept_button)
      elsif terms_form.submit_button
        page = @agent.submit(terms_form)
      end
    end
    
    page
  end

  def find_dividend_announcements(page)
    dividend_links = []
    
    # Look for table with "Today's Announcements" caption
    announcements_table = page.at('table caption:contains("Today\'s Announcements")') ||
                         page.at('table:contains("Today\'s Announcements")') ||
                         page.at('caption:contains("Today\'s Announcements")').parent rescue nil
    
    if announcements_table
      # Look through table rows for dividend/distribution entries
      announcements_table.search('tr').each do |row|
        cells = row.search('td, th')
        
        cells.each do |cell|
          cell_text = cell.text.to_s.strip
          
          # Only process "Dividend/Distribution" announcements, not updates
          if cell_text.match?(/^Dividend\/Distribution\s*-/i)
            # Look for PDF link in this row
            pdf_link = row.at('a[href*=".pdf"], a[href*="/asxpdf/"]')
            
            if pdf_link
              dividend_links << {
                title: cell_text,
                href: pdf_link['href'],
                full_url: pdf_link['href'].start_with?('http') ? pdf_link['href'] : URI.join(BASE_URL, pdf_link['href']).to_s
              }
            else
              # Sometimes the PDF link might be in a different cell
              row.search('a[href*=".pdf"], a[href*="/asxpdf/"]').each do |link|
                dividend_links << {
                  title: cell_text,
                  href: link['href'],
                  full_url: link['href'].start_with?('http') ? link['href'] : URI.join(BASE_URL, link['href']).to_s
                }
              end
            end
          end
        end
      end
    else
      # Search all tables for dividend/distribution announcements
      page.search('table').each do |table|
        table.search('tr').each do |row|
          row_text = row.text.to_s.strip
          
          # Only process "Dividend/Distribution" announcements, not updates
          if row_text.match?(/^Dividend\/Distribution\s*-/i)
            # Look for PDF links in this row
            row.search('a[href*=".pdf"], a[href*="/asxpdf/"]').each do |pdf_link|
              dividend_links << {
                title: row_text.split("\n").first&.strip || pdf_link.text.strip,
                href: pdf_link['href'],
                full_url: pdf_link['href'].start_with?('http') ? pdf_link['href'] : URI.join(BASE_URL, pdf_link['href']).to_s
              }
            end
          end
        end
      end
    end
    
    dividend_links.uniq { |link| link[:href] }
  end

  def download_pdf(link_info)
    begin
      # Add rate limiting delay
      sleep(2)
      
      pdf_url = link_info[:full_url]
      
      # Download the initial response (might be HTML form or PDF)
      pdf_response = @agent.get(pdf_url)
      
      # Check if we got an HTML page with a form instead of a PDF
      content_type = pdf_response.response['content-type'] || ''
      
      if content_type.include?('text/html') || pdf_response.body.include?('<html')
        # Parse the HTML to look for forms
        page = pdf_response
        
        accept_form = page.forms.find { |form| 
          # Check form HTML content
          form_html = form.to_s.downcase
          
          # Also check button values
          button_values = form.buttons.map { |btn| btn.value.to_s.downcase }.join(' ')
          
          search_terms = ['accept', 'continue', 'agree', 'proceed']
          search_terms.any? { |term| form_html.include?(term) || button_values.include?(term) }
        }
        
        if accept_form
          # Look for the appropriate button or checkbox
          accept_button = accept_form.buttons.find { |btn|
            btn_text = btn.value.to_s.downcase
            btn_text.include?('accept') || btn_text.include?('continue') || btn_text.include?('agree') || btn_text.include?('proceed')
          }
          
          accept_checkbox = accept_form.checkboxes.find { |cb|
            cb_name = cb.name.to_s.downcase
            cb_name.include?('accept') || cb_name.include?('agree') || cb_name.include?('terms')
          }
          
          # Check the checkbox if present
          if accept_checkbox
            accept_checkbox.check
          end
          
          # Submit the form
          if accept_button
            pdf_response = @agent.submit(accept_form, accept_button)
          elsif accept_form.submit_button
            pdf_response = @agent.submit(accept_form)
          else
            pdf_response = @agent.submit(accept_form)
          end
          
          # Check the new response
          new_content_type = pdf_response.response['content-type'] || ''
          
          if new_content_type.include?('text/html')
            return nil
          end
        else
          return nil
        end
      end
      
      # At this point we should have a PDF response
      unless pdf_response.body.start_with?('%PDF')
        return nil
      end
      
      # Generate filename
      filename = "#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{link_info[:title].gsub(/[^A-Za-z0-9]/, '_')[0..50]}.pdf"
      pdf_path = File.join(@downloads_dir, filename)
      
      # Save PDF to file
      File.open(pdf_path, 'wb') do |file|
        file.write(pdf_response.body)
      end
      
      # Quick verification that it's actually a PDF
      if File.read(pdf_path, 10).start_with?('%PDF')
        pdf_path
      else
        nil
      end
      
    rescue => e
      nil
    end
  end

  def extract_pdf_data(pdf_path)
    extracted_data = {}
    @csv_headers.each { |header| extracted_data[header] = '' }
    
    begin
      reader = PDF::Reader.new(pdf_path)
      full_text = reader.pages.map(&:text).join("\n")
      
      # Extract specific data points using regex patterns
      extracted_data.merge!(extract_dividend_data(full_text))
      
    rescue => e
      # Handle PDF reading errors silently
    end
    
    extracted_data
  end

  def extract_dividend_data(text)
    data = {}
    
    # Clean up text - remove extra whitespace and normalize
    clean_text = text.gsub(/\s+/, ' ').strip
    
    # Entity name - look for "Entity name" followed by the actual name on next line(s)
    if match = clean_text.match(/Entity name\s+([A-Z][A-Z\s&,.']+?)(?:\s+Security|$)/i)
      data['Entity name'] = match[1].strip
    end
    
    # Try alternative pattern for entity name - look for it in the detailed section
    if (data['Entity name'].nil? || data['Entity name'].empty?) && (match = clean_text.match(/1\.1\s+Name of.*?Entity\s+([A-Z][A-Z\s&,.']+)/i))
      data['Entity name'] = match[1].strip
    end
    
    # Issuer - look for "1.3 ASX issuer code"
    if match = clean_text.match(/1\.3\s+ASX issuer code.*?([A-Z]{2,4})/i)
      data['Issuer'] = match[1].strip
    end
    
    # Security Description - look for "Security on which the Distribution will be paid"
    if match = clean_text.match(/Security on which the Distribution will be paid\s+([A-Z0-9\s\-]+?)(?:\s+Announcement Type|$)/i)
      data['Security Description'] = match[1].strip
    elsif match = clean_text.match(/ASX \+Security Description\s+([A-Z\s]+)/i)
      data['Security Description'] = match[1].strip  
    end
    
    # Date of announcement - look for "Date of this announcement"
    if match = clean_text.match(/Date of this announcement\s+(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Date of this announcement'] = match[1].strip
    end
    
    # Period End - look for "2A.3 The dividend/distribution relates to the financial reporting or payment period ending"
    if match = clean_text.match(/2A\.3.*?period ending.*?ended\/ending.*?(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Period End'] = match[1].strip
    end
    
    # Distribution Amount - look for "Distribution Amount" followed by AUD amount
    if match = clean_text.match(/Distribution Amount.*?AUD\s+([\d.]+)/i)
      data['Distribution Amount'] = match[1].strip
    elsif match = clean_text.match(/3A\.1 Is the ordinary dividend\/distribution estimated at.*?AUD\s+([\d.]+)/im)
      data['Distribution Amount'] = match[1].strip
    elsif match = clean_text.match(/securitydinary Dividend\/distribution amount per\s+AUD\s+([\d.]+)/i)
      data['Distribution Amount'] = match[1].strip
    end
    
    # Ex Date
    if match = clean_text.match(/Ex Date\s+(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Ex Date'] = match[1].strip
    end
    
    # Record Date  
    if match = clean_text.match(/Record Date\s+(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Record Date'] = match[1].strip
    end
    
    # Payment Date
    if match = clean_text.match(/Payment Date\s+(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Payment Date'] = match[1].strip
    end
    
    # Franking percentage - look for "3A.3 Percentage of ordinary dividend/distribution that is franked"
    if match = clean_text.match(/3A\.3.*?franked.*?([\d.]+)\s*%/i)
      data['3A.3 Percentage franked'] = match[1].strip
    elsif match = clean_text.match(/franked\s+\(%\)\s+([\d.]+)\s*%/i)
      data['3A.3 Percentage franked'] = match[1].strip
    elsif match = clean_text.match(/franked ([\d.]+)\s*%/i)  # Try without extra spaces
      data['3A.3 Percentage franked'] = match[1].strip
    end
    
    # DRP discount rate - look for "4A.2" section then find the rate after "4A.3"
    if match = clean_text.match(/4A\.2.*?4A\.3.*?([\d.]+)\s*%/i)
      data['4A.3 DRP discount rate'] = match[1].strip
    end
    
    # DRP Election Date - look for "Last date and time for lodgement of election"
    if match = clean_text.match(/Last date and time for lodgement of election.*?\s+([A-Z][a-z]+\s+[A-Z][a-z]+\s+\d{1,2},\s+\d{4}\s+\d{2}:\d{2}:\d{2})/i)
      data['DRP Election Date'] = match[1].strip
    end
    
    # Period of calculation dates - look for "4A.4 Period of calculation of reinvestment price" then Start/End dates
    if match = clean_text.match(/4A\.4\s+Period of calculation of reinvestment price.*?Start Date.*?End Date.*?(\d{1,2}\/\d{1,2}\/\d{4}).*?(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['Period of calculation of reinvestment price Start Date'] = match[1].strip
      data['Period of calculation of reinvestment price End Date'] = match[2].strip
    end
    
    # DRP securities issue date - look for "4A.7 DRP +securities +issue date" then find the date
    if match = clean_text.match(/4A\.7.*?DRP.*?\+securities.*?\+issue.*?date.*?(\d{1,2}\/\d{1,2}\/\d{4})/i)
      data['4A.7 DRP securities issue date'] = match[1].strip
    end
    
    # New issue check - look for "Will DRP +securities be a new issue?" and extract Yes/No
    if match = clean_text.match(/Will DRP.*?\+securities.*?be a new issue.*?.*?(Yes|No)/i)
      data['4A.8 New issue?'] = match[1].strip
    elsif match = clean_text.match(/4A\.8.*?Will DRP.*?\+securities.*?new issue.*?(Yes|No)/i)
      data['4A.8 New issue?'] = match[1].strip
    elsif match = clean_text.match(/4A\.8.*?new issue.*?(Yes|No)/i)
      data['4A.8 New issue?'] = match[1].strip
    end
    
    data
  end

  def save_to_csv(data_rows)
    # Default to local file, but check for Windows Dropbox path
    csv_file = if File.exist?('/mnt/c/Users/samwi')
                 '/mnt/c/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/dividends.csv'
               elsif File.exist?('C:/Users/samwi')
                 'C:/Users/samwi/Tavira Securities Dropbox/Sam Willis/Australia/DRP/dividends.csv'
               else
                 'dividends.csv'
               end
    
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(csv_file)) unless csv_file == 'dividends.csv'
    
    CSV.open(csv_file, 'w', write_headers: true, headers: @csv_headers) do |csv|
      data_rows.each do |row_data|
        csv_row = @csv_headers.map { |header| row_data[header] || '' }
        csv << csv_row
      end
    end
    
    puts "Data saved to: #{csv_file}"
  end

  def cleanup_debug_files
    # Remove any debug HTML files
    Dir.glob("asx_*.html").each do |file|
      File.delete(file)
    end
    
    # Clean up the asx_dividends directory if it exists
    if Dir.exist?(@downloads_dir)
      Dir.glob(File.join(@downloads_dir, "*.html")).each do |file|
        File.delete(file)
      end
      
      # Remove empty PDF directory if no files left
      if Dir.empty?(@downloads_dir)
        Dir.rmdir(@downloads_dir)
      end
    end
  end
end

# Check for required gems
def check_dependencies
  missing_gems = []
  
  begin
    require 'mechanize'
  rescue LoadError
    missing_gems << 'mechanize'
  end
  
  begin
    require 'pdf-reader'
  rescue LoadError
    missing_gems << 'pdf-reader'
  end
  
  begin
    require 'selenium-webdriver'
  rescue LoadError
    missing_gems << 'selenium-webdriver'
  end
  
  unless missing_gems.empty?
    puts "Missing required gems. Please install:"
    missing_gems.each { |gem| puts "   gem install #{gem}" }
    exit 1
  end
  
  # Check for Chrome browser
  begin
    `which google-chrome || which chrome || which chromium`
    if $?.exitstatus != 0
      puts "Chrome not found. Please install Chrome browser for Selenium to work."
      puts "   On macOS: brew install --cask google-chrome"
      puts "   On Ubuntu: sudo apt-get install google-chrome-stable"
    end
  rescue
    # Continue if Chrome check fails
  end
end

# Main execution
if __FILE__ == $0
  puts "ASX Dividend Scraper"
  puts "=" * 30
  
  check_dependencies
  
  scraper = AsxDividendScraper.new
  scraper.scrape_and_process
  
  puts "Script completed!"
end