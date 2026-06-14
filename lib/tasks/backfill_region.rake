# Demo/dev data hygiene: many seeded applications were created before the seed
# set :region, so they defaulted to "US" despite carrying Australian (or other)
# addresses. That made the console region picker look broken — an AU-addressed
# contract still showed under "US". This derives each application's region from
# its own address and corrects mismatches.
#
# DEV/DEMO ONLY. It refuses to run in production: parsing a free-text address
# must never relabel real customer data. Idempotent — re-running is a no-op once
# regions match. Only updates applications that HAVE an address; address-less
# early-pipeline rows are left untouched.
namespace :region do
  # Order matters: check the most specific signals first.
  REGION_PATTERNS = {
    "AU" => /\b(NSW|VIC|QLD|SA|WA|TAS|NT|ACT)\b|\bAustralia\b/i,
    "NZ" => /\bNew Zealand\b|\bAuckland\b|\bWellington\b|\bChristchurch\b/i,
    "UK" => /\bUnited Kingdom\b|\bLondon\b|\bManchester\b|\bEngland\b|\bScotland\b/i,
    "US" => /\b(AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WV|WI|WY)\s*\d{5}\b|\bUSA?\b|\bUnited States\b/
  }.freeze

  def region_for(address)
    REGION_PATTERNS.each { |code, pattern| return code if address =~ pattern }
    nil
  end

  desc "Backfill Application#region from its address (DEV/DEMO ONLY)"
  task backfill_applications: :environment do
    if Rails.env.production?
      abort "Refusing to run in production — address parsing must not relabel real data."
    end

    changed = Hash.new(0)
    unmatched = 0

    Application.where.not(address: [ nil, "" ]).find_each do |app|
      mapped = region_for(app.address.to_s)
      if mapped.nil?
        unmatched += 1
        next
      end
      next if app.region == mapped

      changed["#{app.region} -> #{mapped}"] += 1
      app.update_columns(region: mapped) # skip callbacks/validations — data hygiene only
    end

    puts "Region backfill complete."
    if changed.empty?
      puts "  Nothing to change — every addressed application already matches."
    else
      changed.sort.each { |transition, count| puts "  #{transition}: #{count}" }
    end
    puts "  Addresses with no recognisable region (left as-is): #{unmatched}" if unmatched.positive?
    puts "  Region distribution now: #{Application.group(:region).count}"
  end
end
