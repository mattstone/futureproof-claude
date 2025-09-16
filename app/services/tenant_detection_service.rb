class TenantDetectionService
  def self.lender_from_domain(domain)
    case domain
    when 'futureproofinancial.co', 'www.futureproofinancial.co', 'demo.futureproofinancial.co', 'demo.futureprooffinancial.co'
      # Use the existing futureproof lender
      Lender.lender_type_futureproof.first
    when 'app.futureproof.com', 'futureproof.com', 'www.futureproof.com'
      Lender.lender_type_futureproof.first
    when 'localhost', '127.0.0.1', '::1'
      # For development/testing, use the futureproof lender
      Lender.lender_type_futureproof.first
    else
      # Default to futureproof lender for unknown domains
      Lender.lender_type_futureproof.first
    end
  end

  def self.admin_domain?(domain)
    ['futureproofinancial.co', 'www.futureproofinancial.co', 'demo.futureproofinancial.co', 'demo.futureprooffinancial.co'].include?(domain)
  end
end