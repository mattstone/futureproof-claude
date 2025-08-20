#!/usr/bin/env ruby

# Master test runner for all Futureproof system tests
# This script runs all the browser tests we've created during development

require_relative '../config/environment'

class FutureproofTestRunner
  def self.run
    puts "🚀 Futureproof System - Master Test Runner"
    puts "=" * 80
    puts "Running all browser tests created during development..."
    
    tests = [
      {
        name: "Lender Clauses Version Control System - Quick Verification",
        file: "test/lender_clauses_verification.rb",
        description: "Tests the complete version control system for lender clauses"
      },
      {
        name: "Lenders Layout Verification", 
        file: "test/lenders_layout_verification.rb",
        description: "Tests the new card-based lenders layout"
      },
      {
        name: "Clause Management UI - Comprehensive Verification",
        file: "test/clause_management_ui_verification.rb",
        description: "Tests the complete clause management interface and functionality"
      },
      {
        name: "Clause Markup System - Comprehensive Verification",
        file: "test/clause_markup_system_verification.rb", 
        description: "Tests the markup functionality, preview system, and UI components"
      }
    ]
    
    results = []
    
    tests.each_with_index do |test, index|
      puts "\n" + "=" * 80
      puts "📋 Test #{index + 1}/#{tests.length}: #{test[:name]}"
      puts "📝 Description: #{test[:description]}"
      puts "📁 File: #{test[:file]}"
      puts "=" * 80
      
      begin
        if File.exist?(test[:file])
          start_time = Time.now
          result = system("ruby #{test[:file]}")
          end_time = Time.now
          duration = (end_time - start_time).round(2)
          
          if result
            puts "\n✅ PASSED (#{duration}s)"
            results << { test: test[:name], status: "PASSED", duration: duration }
          else
            puts "\n❌ FAILED (#{duration}s)"
            results << { test: test[:name], status: "FAILED", duration: duration }
          end
        else
          puts "\n⚠️  SKIPPED - File not found: #{test[:file]}"
          results << { test: test[:name], status: "SKIPPED", duration: 0 }
        end
      rescue => e
        puts "\n💥 ERROR: #{e.message}"
        results << { test: test[:name], status: "ERROR", duration: 0 }
      end
    end
    
    # Print summary
    puts "\n" + "=" * 80
    puts "📊 TEST SUMMARY"
    puts "=" * 80
    
    passed = results.count { |r| r[:status] == "PASSED" }
    failed = results.count { |r| r[:status] == "FAILED" }
    skipped = results.count { |r| r[:status] == "SKIPPED" }
    errors = results.count { |r| r[:status] == "ERROR" }
    total_time = results.sum { |r| r[:duration] }
    
    results.each do |result|
      status_icon = case result[:status]
      when "PASSED" then "✅"
      when "FAILED" then "❌"
      when "SKIPPED" then "⚠️"
      when "ERROR" then "💥"
      end
      
      duration_text = result[:duration] > 0 ? " (#{result[:duration]}s)" : ""
      puts "#{status_icon} #{result[:test]}#{duration_text}"
    end
    
    puts "\n" + "-" * 80
    puts "📈 RESULTS:"
    puts "   ✅ Passed: #{passed}"
    puts "   ❌ Failed: #{failed}" if failed > 0
    puts "   ⚠️  Skipped: #{skipped}" if skipped > 0
    puts "   💥 Errors: #{errors}" if errors > 0
    puts "   ⏱️  Total Time: #{total_time}s"
    
    if failed == 0 && errors == 0
      puts "\n🎉 ALL TESTS SUCCESSFUL!"
      puts "✅ Futureproof system is working correctly"
      return true
    else
      puts "\n⚠️  SOME TESTS FAILED"
      puts "❌ Please review failed tests above"
      return false
    end
  end
end

# Run all tests if this file is executed directly
if __FILE__ == $0
  success = FutureproofTestRunner.run
  exit(success ? 0 : 1)
end