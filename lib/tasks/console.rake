namespace :console do
  desc "Lint Console views/components for structural consistency (no inline styles, no raw tables, no legacy admin classes/paths)"
  task lint: :environment do
    offenses = Console::ViewLinter.offenses

    if offenses.any?
      puts offenses
      abort "❌ console:lint — #{offenses.size} offence(s) in Console views"
    else
      puts "✅ console:lint clean (#{Console::ViewLinter.files.size} files)"
    end
  end
end
