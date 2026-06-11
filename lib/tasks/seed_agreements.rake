namespace :agreements do
  desc "Seed sample agreements with signatures for test data"
  task seed: :environment do
    admin = User.find_by(admin: true)
    unless admin
      puts "ERROR: No admin user found"
      exit 1
    end

    created = 0
    signed = 0

    # Map party country codes to jurisdiction codes
    jurisdiction_map = {
      "AUSTRALIA" => "AU", "AU" => "AU",
      "UNITED STATES" => "US", "US" => "US",
      "NEW ZEALAND" => "NZ", "NZ" => "NZ",
      "UNITED KINGDOM" => "UK", "UK" => "UK"
    }

    # --- Lender Agreements ---
    lenders = Lender.where.not(lender_type: :futureproof).limit(6)
    lenders.each do |lender|
      jurisdiction = jurisdiction_map[lender.country] || "AU"
      template = LegalDocument.find_by(document_type: "lender_contract", jurisdiction: jurisdiction, is_active: true)
      next unless template

      next if Agreement.exists?(agreeable: lender, legal_document: template)

      agreement = Agreement.generate_from_template(
        legal_document: template,
        agreeable: lender,
        created_by: admin,
        customizations: { "Lender Name" => lender.name, "Number" => "ACN #{rand(100_000_000..999_999_999)}" }
      )

      if agreement.save
        puts "  CREATE: #{agreement.title}"
        created += 1

        # Simulate signing workflow for some
        if created <= 4
          agreement.send_for_signing!

          # Counterparty signs
          agreement.record_signature!(
            role: "counterparty",
            signer_name: "#{Faker::Name.name rescue 'John Smith'}",
            signer_email: lender.contact_email || "contact@#{lender.name.parameterize}.com",
            signer_title: "Director",
            typed_signature: "#{Faker::Name.name rescue 'John Smith'}",
            ip_address: "203.#{rand(0..255)}.#{rand(0..255)}.#{rand(0..255)}",
            user_agent: "Mozilla/5.0"
          )
          signed += 1
          puts "    SIGNED: counterparty"

          # FutureProof signs (first 2 fully executed)
          if created <= 2
            agreement.record_signature!(
              role: "futureproof",
              signer_name: admin.display_name,
              signer_email: admin.email,
              signer_title: "CEO",
              typed_signature: admin.display_name,
              ip_address: "10.0.0.1",
              user_agent: "Mozilla/5.0"
            )
            signed += 1
            puts "    SIGNED: futureproof (FULLY EXECUTED)"
          end
        end
      else
        puts "  ERROR: #{agreement.errors.full_messages.join(', ')}"
      end
    end

    # --- Wholesale Funder Agreements ---
    WholesaleFunder.limit(4).each do |funder|
      jurisdiction = jurisdiction_map[funder.country] || "US"
      template = LegalDocument.find_by(document_type: "wholesale_funder_contract", jurisdiction: jurisdiction, is_active: true)
      next unless template

      next if Agreement.exists?(agreeable: funder, legal_document: template)

      agreement = Agreement.generate_from_template(
        legal_document: template,
        agreeable: funder,
        created_by: admin,
        customizations: { "Funder Name" => funder.name }
      )

      if agreement.save
        puts "  CREATE: #{agreement.title}"
        created += 1

        # First 2 fully executed, third sent
        if created <= 8
          agreement.send_for_signing!

          agreement.record_signature!(
            role: "counterparty",
            signer_name: "#{Faker::Name.name rescue 'Jane Doe'}",
            signer_email: "finance@#{funder.name.parameterize}.com",
            signer_title: "Managing Director",
            typed_signature: "#{Faker::Name.name rescue 'Jane Doe'}",
            ip_address: "198.#{rand(0..255)}.#{rand(0..255)}.#{rand(0..255)}",
            user_agent: "Mozilla/5.0"
          )
          signed += 1

          agreement.record_signature!(
            role: "futureproof",
            signer_name: admin.display_name,
            signer_email: admin.email,
            signer_title: "CEO",
            typed_signature: admin.display_name,
            ip_address: "10.0.0.1",
            user_agent: "Mozilla/5.0"
          )
          signed += 1
          puts "    FULLY EXECUTED"
        end
      end
    end

    # --- Broker Agreements ---
    Broker.limit(4).each do |broker|
      jurisdiction = jurisdiction_map[broker.jurisdiction] || "AU"
      template = LegalDocument.find_by(document_type: "broker_contract", jurisdiction: jurisdiction, is_active: true)
      next unless template

      next if Agreement.exists?(agreeable: broker, legal_document: template)

      agreement = Agreement.generate_from_template(
        legal_document: template,
        agreeable: broker,
        created_by: admin,
        customizations: { "Partner Name" => broker.name }
      )

      if agreement.save
        puts "  CREATE: #{agreement.title}"
        created += 1

        # First broker fully executed, second sent
        agreement.send_for_signing!

        agreement.record_signature!(
          role: "counterparty",
          signer_name: broker.name,
          signer_email: broker.email,
          signer_title: "Principal Broker",
          typed_signature: broker.name,
          ip_address: "122.#{rand(0..255)}.#{rand(0..255)}.#{rand(0..255)}",
          user_agent: "Mozilla/5.0"
        )
        signed += 1

        if created.odd?
          agreement.record_signature!(
            role: "futureproof",
            signer_name: admin.display_name,
            signer_email: admin.email,
            signer_title: "CEO",
            typed_signature: admin.display_name,
            ip_address: "10.0.0.1",
            user_agent: "Mozilla/5.0"
          )
          signed += 1
          puts "    FULLY EXECUTED"
        else
          puts "    COUNTERPARTY SIGNED (awaiting FP)"
        end
      end
    end

    puts "\nDone: #{created} agreements created, #{signed} signatures recorded"
    puts "Status breakdown:"
    Agreement.group(:status).count.each { |s, c| puts "  #{s}: #{c}" }
  end
end
