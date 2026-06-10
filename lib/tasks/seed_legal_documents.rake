namespace :legal do
  desc "Seed LegalDocument records from static ERB legal views for all jurisdictions"
  task seed: :environment do
    # Document definitions: maps document_type to view path pattern and party_type
    documents = [
      # Universal documents (for all parties)
      { type: "privacy_policy", title_prefix: "Privacy Policy", party_type: "universal",
        view_pattern: "legal/privacy/privacy_%{region}" },
      { type: "terms_of_use", title_prefix: "Terms of Use", party_type: "universal",
        view_pattern: "legal/terms/terms_%{region}" },
      { type: "terms_conditions", title_prefix: "Terms & Conditions", party_type: "universal",
        view_pattern: "legal/terms/terms_%{region}" },

      # Customer contracts
      { type: "customer_contract", title_prefix: "Customer Mortgage Contract", party_type: "customer",
        view_pattern: "legal/contracts/mortgage_%{region}" },

      # Lender agreements
      { type: "lender_contract", title_prefix: "Lender Agreement", party_type: "lender",
        view_pattern: "legal/agreements/lender_%{region}" },

      # Wholesale funder agreements
      { type: "wholesale_funder_contract", title_prefix: "Wholesale Funder Agreement", party_type: "wholesale_funder",
        view_pattern: "legal/agreements/wholesale_funder_%{region}" },

      # Broker/referral partner agreements
      { type: "broker_contract", title_prefix: "Broker Agreement", party_type: "broker",
        view_pattern: "legal/agreements/referral_partner_%{region}" },

      # Investment provider agreements
      { type: "investment_provider_contract", title_prefix: "Investment Provider Agreement", party_type: "investment_provider",
        view_pattern: "legal/agreements/investment_management_%{region}" }
    ]

    jurisdictions = {
      "US" => "United States",
      "AU" => "Australia",
      "NZ" => "New Zealand",
      "UK" => "United Kingdom"
    }

    created = 0
    skipped = 0
    warnings = 0

    documents.each do |doc_def|
      jurisdictions.each do |code, name|
        # Skip if an active document already exists
        existing = LegalDocument.where(
          document_type: doc_def[:type],
          jurisdiction: code,
          party_type: doc_def[:party_type],
          is_active: true
        ).first

        if existing
          puts "  SKIP: #{doc_def[:title_prefix]} - #{name} (active v#{existing.version} exists)"
          skipped += 1
          next
        end

        # Read the static ERB view to get HTML content
        html_content = render_legal_view(doc_def[:view_pattern], code)

        if html_content.blank?
          puts "  WARN: No view content for #{doc_def[:type]}_#{code.downcase}"
          warnings += 1
          next
        end

        # Calculate next version
        existing_versions = LegalDocument.where(
          document_type: doc_def[:type], jurisdiction: code, party_type: doc_def[:party_type]
        ).pluck(:version).compact.map { |v| Gem::Version.new(v) rescue Gem::Version.new("0") }
        version = existing_versions.empty? ? "1.0" : "#{existing_versions.max.segments[0]}.#{(existing_versions.max.segments[1] || 0) + 1}"

        doc = LegalDocument.new(
          document_type: doc_def[:type],
          jurisdiction: code,
          party_type: doc_def[:party_type],
          title: "#{doc_def[:title_prefix]} - #{name}",
          version: version,
          content: html_content,
          effective_from: Date.new(2026, 3, 17),
          status: :active,
          is_active: true,
          is_draft: false
        )

        # Also set rich_content with the HTML
        doc.rich_content = html_content

        if doc.save
          puts "  CREATE: #{doc.display_name}"
          created += 1
        else
          puts "  ERROR: #{doc_def[:title_prefix]} - #{name}: #{doc.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nDone: #{created} created, #{skipped} skipped, #{warnings} warnings"
  end

  private

  def render_legal_view(view_pattern, jurisdiction_code)
    region = jurisdiction_code.downcase
    view_path = view_pattern % { region: region }

    # Read the ERB file directly and extract the HTML content
    file_path = Rails.root.join("app", "views", "#{view_path}.html.erb")
    return nil unless File.exist?(file_path)

    # Read raw file content — strip ERB tags for clean HTML
    raw = File.read(file_path)

    # If this is a render partial call, follow it to the partial
    if raw.strip.match?(/\A<%=\s*render\s/)
      partial_match = raw.match(/render\s+['"]([^'"]+)['"]/)
      if partial_match
        partial_path = partial_match[1]
        # Convert partial reference to file path (add _ prefix for partial)
        parts = partial_path.split("/")
        parts[-1] = "_#{parts[-1]}"
        partial_file = Rails.root.join("app", "views", "#{parts.join('/')}.html.erb")
        if File.exist?(partial_file)
          raw = File.read(partial_file)
        end
      end
    end

    # Remove ERB processing tags but keep the HTML structure
    html = raw.gsub(/<%.*?%>/m, "")

    # Clean up empty lines from removed ERB tags
    html = html.gsub(/\n\s*\n\s*\n/, "\n\n").strip

    html
  end
end
