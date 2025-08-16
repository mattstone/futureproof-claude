#!/usr/bin/env ruby

# Fix over-replacement patterns caused by comprehensive fix script
# This script fixes patterns like "wholesale_funder" back to "wholesale_funder"

require 'fileutils'

class OverReplacementFixer
  def initialize
    @base_path = '/Users/zen/projects/futureproof/futureproof'
    @files_changed = 0
    @total_replacements = 0
  end

  def run
    puts "🔧 Fixing over-replacement patterns in Rails app..."
    
    # Define all the over-replacement patterns that need fixing
    @replacement_patterns = [
      # Variable names and method calls
      ['wholesale_funder', 'wholesale_funder'],
      ['wholesale_funder', 'wholesale_funder'],
      ['@wholesale_funder', '@wholesale_funder'],
      ['@wholesale_funder', '@wholesale_funder'],
      
      # Class names  
      ['WholesaleFunder', 'WholesaleFunder'],
      ['WholesaleFunder', 'WholesaleFunder'],
      ['WholesaleFunderPool', 'WholesaleFunderPool'],
      ['wholesale_funder_pool', 'wholesale_funder_pool'],
      ['WholesaleFunder', 'WholesaleFunder'],
      
      # Route helpers and paths
      ['admin_wholesale_funders_path', 'admin_wholesale_funders_path'],
      ['admin_wholesale_funder_path', 'admin_wholesale_funder_path'],
      ['new_admin_wholesale_funder_path', 'new_admin_wholesale_funder_path'],
      ['edit_admin_wholesale_funder_path', 'edit_admin_wholesale_funder_path'],
      ['search_admin_wholesale_funders_path', 'search_admin_wholesale_funders_path'],
      ['admin_wholesale_funder_wholesale_funder_pool_path', 'admin_wholesale_funder_funder_pool_path'],
      ['new_admin_wholesale_funder_wholesale_funder_pool_path', 'new_admin_wholesale_funder_funder_pool_path'],
      ['edit_admin_wholesale_funder_wholesale_funder_pool_path', 'edit_admin_wholesale_funder_funder_pool_path'],
      
      # Controller names
      ["controller_name == 'wholesale_funders'", "controller_name == 'wholesale_funders'"],
      ["controller_name == 'wholesale_funders'", "controller_name == 'wholesale_funders'"],
      
      # CSS classes and IDs
      ['wholesale-funders-', 'wholesale-funders-'],
      ['wholesale-funder-', 'wholesale-funder-'],
      ['wholesale-funders-', 'wholesale-funders-'],
      ['wholesale-funder-', 'wholesale-funder-'],
      
      # Text content
      ['Wholesale WholesaleFunder', 'WholesaleFunder'],
      ['wholesale_funder', 'wholesale_funder'],
      ['Wholesale WholesaleFunders', 'WholesaleFunders'],
      ['wholesale_funders', 'wholesale_funders'],
      
      # File and directory references
      ['wholesale_funders', 'wholesale_funders'],
      ['wholesale_funder', 'wholesale_funder'],
      ['wholesale_funders', 'wholesale_funders'],
      ['wholesale_funder', 'wholesale_funder'],
      
      # Method calls and associations
      ['.wholesale_funder_pools', '.funder_pools'],
      ['wholesale_funder_pool_id', 'wholesale_funder_pool_id'],
      
      # Dashboard method fixes
      ['WholesaleFunderPool.', 'WholesaleFunderPool.'],
      ['wholesale_funder_pool_id:', 'wholesale_funder_pool_id:']
    ]
    
    # Find all files to process
    file_patterns = [
      'app/**/*.rb',
      'app/**/*.erb', 
      'config/**/*.rb',
      'db/**/*.rb',
      'lib/**/*.rb',
      'test/**/*.rb'
    ]
    
    files_to_process = []
    file_patterns.each do |pattern|
      files_to_process.concat(Dir.glob(File.join(@base_path, pattern)))
    end
    
    files_to_process.uniq!
    
    puts "Found #{files_to_process.size} files to check"
    
    # Process each file
    files_to_process.each do |file_path|
      process_file(file_path)
    end
    
    puts "\n✅ Over-replacement fix complete!"
    puts "📁 Files changed: #{@files_changed}"
    puts "🔄 Total replacements: #{@total_replacements}"
  end

  private

  def process_file(file_path)
    return unless File.file?(file_path)
    
    begin
      original_content = File.read(file_path)
      modified_content = original_content.dup
      file_changes = 0
      
      # Apply all replacement patterns
      @replacement_patterns.each do |old_pattern, new_pattern|
        if modified_content.include?(old_pattern)
          count = modified_content.scan(old_pattern).length
          modified_content.gsub!(old_pattern, new_pattern)
          file_changes += count
          @total_replacements += count
        end
      end
      
      # Only write if changes were made
      if file_changes > 0
        File.write(file_path, modified_content)
        @files_changed += 1
        puts "✏️  #{file_path.sub(@base_path + '/', '')} (#{file_changes} fixes)"
      end
      
    rescue => e
      puts "❌ Error processing #{file_path}: #{e.message}"
    end
  end
end

# Run the fixer
if __FILE__ == $0
  fixer = OverReplacementFixer.new
  fixer.run
end