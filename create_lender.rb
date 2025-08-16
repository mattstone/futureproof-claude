# Check if the futureproof lender exists
futureproof_lender = Lender.find_by(lender_type: :futureproof)
if futureproof_lender
  puts 'Futureproof lender exists: ' + futureproof_lender.name
else
  puts 'Creating Futureproof lender...'
  futureproof_lender = Lender.create!(
    name: 'Futureproof Financial Pty Ltd',
    lender_type: :futureproof,
    address: 'Wework Barangaroo, Sydney',
    postcode: '2000',
    country: 'Australia',
    contact_email: 'info@futureprooffinancial.co',
    contact_telephone: '0432212713',
    contact_telephone_country_code: '+61'
  )
  puts 'Created Futureproof lender: ' + futureproof_lender.name
end