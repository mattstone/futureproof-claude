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

  desc "Print every console GET path with ids resolved from the current database (for bin/console-verify)"
  task crawl_paths: :environment do
    Rails.application.routes.routes.each do |route|
      next unless route.verb == "GET" && route.path.spec.to_s.start_with?("/console")

      required = route.required_parts - [ :format ]
      if required.empty?
        puts route.format({})
        next
      end

      controller = route.defaults[:controller]
      params =
        case controller
        when "console/funder_pools"
          pool = FunderPool.first
          pool && { wholesale_funder_id: pool.wholesale_funder_id, id: pool.id }
        when "console/wholesale_funder_contracts"
          doc = WholesaleFunderContract.first
          doc && { wholesale_funder_id: doc.wholesale_funder_id, id: doc.id }
        when "console/mortgage_contracts"
          contract = MortgageContract.where.not(mortgage_id: nil).first
          contract && { mortgage_id: contract.mortgage_id, id: contract.id }
        when "console/broker_commission_rates"
          rate = BrokerCommissionRate.first
          rate && { lender_id: rate.lender_id, id: rate.id }
        when "console/lender_clauses"
          Lender.first && { lender_id: Lender.first.id }
        when "console/prompts"
          { key: PromptFiles.slots_for(:runtime).first.key }
        else
          model = controller.split("/").last.classify.safe_constantize
          record = model&.first
          record && { id: record.id }
        end

      if params
        puts route.format(params)
      else
        warn "SKIP (no data): #{route.path.spec}"
      end
    end
  end
end
