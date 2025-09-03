namespace :email_templates do
  desc "Lint all email templates for styling issues and regressions"
  task lint: :environment do
    puts "🔍 Email Template Linting - Checking for styling regressions..."
    
    issues_found = 0
    
    EmailTemplate.active.each do |template|
      puts "\n📧 Checking template: #{template.name} (#{template.template_type})"
      
      # Validate the template
      unless template.valid?
        puts "❌ VALIDATION ERRORS:"
        template.errors.full_messages.each { |msg| puts "   - #{msg}" }
        issues_found += 1
      else
        puts "✅ Valid"
      end
      
      # Specific checks for security templates
      if template.template_type == 'security_notification'
        puts "🔒 Running security template specific checks..."
        
        # Check for proper padding
        if template.content.include?('Sign-in Details') && template.content.include?('padding: 20px 24px')
          puts "✅ Sign-in details box has proper padding"
        elsif template.content.include?('Sign-in Details')
          puts "⚠️  WARNING: Sign-in details found but padding might be insufficient"
        end
        
        # Check for other common issues
        if template.content.include?('padding: 0')
          puts "⚠️  WARNING: Found zero padding - ensure this is intentional"
        end
      end
      
      # Check for common email formatting issues
      common_issues = {
        'style attributes without quotes' => /style=[^"][^>]*>/,
        'missing border-collapse on tables' => /<table(?![^>]*border-collapse)/,
        'inline styles without fallbacks' => /background-color:\s*#[0-9a-f]{6}(?!.*border)/i
      }
      
      common_issues.each do |issue_name, pattern|
        if template.content.match?(pattern)
          puts "⚠️  POTENTIAL ISSUE: #{issue_name}"
        end
      end
    end
    
    puts "\n📊 SUMMARY:"
    if issues_found == 0
      puts "✅ All email templates passed validation!"
      puts "✅ No styling regressions detected."
    else
      puts "❌ Found #{issues_found} template(s) with validation issues."
      puts "❌ Please review and fix the issues above."
      exit 1
    end
  end

  desc "Fix common email template issues automatically"
  task fix_common_issues: :environment do
    puts "🔧 Auto-fixing common email template issues..."
    
    EmailTemplate.where(template_type: 'security_notification').each do |template|
      original_content = template.content
      updated_content = original_content.dup
      changes_made = false
      
      # Fix zero padding in security details sections
      if updated_content.match?(/td\s+style="[^"]*padding:\s*0[^"]*"[^>]*>.*?(Sign-in Details|Time:|Browser:|IP Address:|Location:)/mi)
        updated_content.gsub!(/td(\s+style="[^"]*?)padding:\s*0([^"]*"[^>]*>.*?(?:Sign-in Details|Time:|Browser:|IP Address:|Location:))/mi) do
          "td#{$1}padding: 20px 24px#{$2}"
        end
        changes_made = true
        puts "✅ Fixed zero padding in sign-in details for: #{template.name}"
      end
      
      # Save changes if any were made
      if changes_made
        template.content = updated_content
        if template.valid?
          template.save!
          puts "💾 Saved fixes for template: #{template.name}"
        else
          puts "❌ Could not save fixes for #{template.name} due to validation errors:"
          template.errors.full_messages.each { |msg| puts "   - #{msg}" }
        end
      else
        puts "ℹ️  No fixes needed for: #{template.name}"
      end
    end
    
    puts "🎉 Auto-fix complete!"
  end

  desc "Generate email template documentation"
  task document: :environment do
    puts "📚 Generating email template documentation..."
    
    File.open(Rails.root.join('EMAIL_TEMPLATE_GUIDELINES.md'), 'w') do |file|
      file.puts "# Email Template Style Guidelines"
      file.puts ""
      file.puts "## Critical Rules"
      file.puts ""
      file.puts "### Security Notification Templates"
      file.puts "- **NEVER** use `padding: 0;` in sign-in details table cells"
      file.puts "- **ALWAYS** use minimum `padding: 20px 24px;` for sign-in details boxes"
      file.puts "- Reason: Zero padding makes text appear right against the border, looking unprofessional"
      file.puts ""
      file.puts "### General Email Formatting"
      file.puts "- Always use `border-collapse: collapse;` on tables"
      file.puts "- Quote all style attribute values"
      file.puts "- Test templates in multiple email clients"
      file.puts ""
      file.puts "## Validation"
      file.puts "Run `bin/rails email_templates:lint` to check for style regressions"
      file.puts ""
      file.puts "## Generated on: #{Time.current}"
    end
    
    puts "✅ Documentation generated: EMAIL_TEMPLATE_GUIDELINES.md"
  end
end