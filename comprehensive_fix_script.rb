#!/usr/bin/env ruby

puts "=== Comprehensive Fix Script for Remaining Model References ==="

require 'find'

# Define the file extensions to search
extensions = ['.rb', '.erb', '.yml']

# Define patterns to search for and their replacements
patterns = {
  # Old model class references
  'class Company' => 'class Lender',
  'class Funder' => 'class WholesaleFunder',
  
  # Model instantiation and references
  'Company.find' => 'Lender.find',
  'Company.where' => 'Lender.where',
  'Company.create' => 'Lender.create',
  'Company.order' => 'Lender.order',
  'Company.includes' => 'Lender.includes',
  'Company.joins' => 'Lender.joins',
  'Company.first' => 'Lender.first',
  'Company.last' => 'Lender.last',
  'Company.all' => 'Lender.all',
  'Company.count' => 'Lender.count',
  
  'Funder.find' => 'WholesaleFunder.find',
  'Funder.where' => 'WholesaleFunder.where',
  'Funder.create' => 'WholesaleFunder.create',
  'Funder.order' => 'WholesaleFunder.order',
  'Funder.includes' => 'WholesaleFunder.includes',
  'Funder.joins' => 'WholesaleFunder.joins',
  'Funder.first' => 'WholesaleFunder.first',
  'Funder.last' => 'WholesaleFunder.last',
  'Funder.all' => 'WholesaleFunder.all',
  'Funder.count' => 'WholesaleFunder.count',
  
  # Instance variable references
  '@company' => '@lender',
  '@funder' => '@wholesale_funder',
  
  # Parameter and attribute references
  'company_id' => 'lender_id',
  'funder_id' => 'wholesale_funder_id',
  'company_type' => 'lender_type',
  
  # Enum method references
  'company_type_master' => 'lender_type_futureproof',
  'company_type_broker' => 'lender_type_lender',
  
  # Route helpers
  'admin_company_path' => 'admin_lender_path',
  'admin_companies_path' => 'admin_lenders_path',
  'edit_admin_company_path' => 'edit_admin_lender_path',
  'new_admin_company_path' => 'new_admin_lender_path',
  
  'admin_funder_path' => 'admin_wholesale_funder_path',
  'admin_funders_path' => 'admin_wholesale_funders_path',
  'edit_admin_funder_path' => 'edit_admin_wholesale_funder_path',
  'new_admin_funder_path' => 'new_admin_wholesale_funder_path',
  'admin_funder_funder_pool_path' => 'admin_wholesale_funder_funder_pool_path',
  'edit_admin_funder_funder_pool_path' => 'edit_admin_wholesale_funder_funder_pool_path',
  'new_admin_funder_funder_pool_path' => 'new_admin_wholesale_funder_funder_pool_path',
  
  # Association references
  ':company' => ':lender',
  ':funder' => ':wholesale_funder',
  'belongs_to :company' => 'belongs_to :lender',
  'belongs_to :funder' => 'belongs_to :wholesale_funder',
  'has_many :companies' => 'has_many :lenders',
  'has_many :funders' => 'has_many :wholesale_funders',
  
  # Table and column references in queries
  'companies.' => 'lenders.',
  'funders.' => 'wholesale_funders.',
  
  # Method references
  'broker_admin?' => 'lender_admin?',
  'admin_company' => 'admin_lender',
  'set_company' => 'set_lender',
  'set_funder' => 'set_wholesale_funder',
  
  # Display text
  'Company' => 'Lender',
  'Funder' => 'Wholesale Funder',
  'company' => 'lender',
  'funder' => 'wholesale funder'
}

# Files to exclude from processing
exclude_files = [
  'comprehensive_fix_script.rb',
  'db/schema.rb',
  'db/migrate/',
  'test/fixtures/',
  'log/',
  'tmp/',
  '.git/'
]

def should_exclude_file?(file_path)
  exclude_files = [
    'comprehensive_fix_script.rb',
    'db/schema.rb',
    'test/fixtures/',
    'log/',
    'tmp/',
    '.git/'
  ]
  
  exclude_files.any? { |pattern| file_path.include?(pattern) } ||
    file_path.include?('db/migrate/') ||
    file_path.end_with?('_test.rb')
end

def process_file(file_path, patterns)
  return if should_exclude_file?(file_path)
  
  begin
    content = File.read(file_path)
    original_content = content.dup
    
    patterns.each do |old_pattern, new_pattern|
      content.gsub!(old_pattern, new_pattern)
    end
    
    if content != original_content
      File.write(file_path, content)
      puts "✓ Updated: #{file_path}"
      return true
    end
  rescue => e
    puts "✗ Error processing #{file_path}: #{e.message}"
  end
  
  false
end

# Process all files
updated_files = []

Find.find('.') do |path|
  next if File.directory?(path)
  next unless extensions.any? { |ext| path.end_with?(ext) }
  
  if process_file(path, patterns)
    updated_files << path
  end
end

puts "\n=== Summary ==="
puts "Files updated: #{updated_files.count}"

if updated_files.count > 0
  puts "\nUpdated files:"
  updated_files.each { |file| puts "  - #{file}" }
end

puts "\n=== Fix Script Complete ==="