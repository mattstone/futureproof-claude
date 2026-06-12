# Sample data for email template previews and test sends — extracted from
# the legacy admin controller so the console stays slim. `preview_for` is
# deterministic; `test_for` randomises for realistic test sends.
class Console::EmailTemplateSampleData
  class << self
    def preview_for(template, user)
      case template.template_type
      when "verification"
        { user: user, verification_code: "123456", expires_at: 15.minutes.from_now }
      when "application_submitted"
        application = Application.joins(:user, :mortgage).first
        mortgage = application&.mortgage || Mortgage.first
        {
          user: user,
          application: application || sample_application(user, mortgage),
          mortgage: mortgage || sample_mortgage
        }
      when "security_notification"
        { user: user, browser_info: "Chrome 120.0 on macOS", ip_address: "192.168.1.1",
          location: "Sydney, Australia", sign_in_time: Time.current }
      else
        { user: user }
      end
    end

    def test_for(template, user)
      case template.template_type
      when "verification"
        { user: user,
          verification: { verification_code: rand(100_000..999_999).to_s,
                          expires_at: 30.minutes.from_now,
                          formatted_expires_at: 30.minutes.from_now.strftime("%I:%M %p") } }
      when "application_submitted"
        home_value = [ 750_000, 850_000, 950_000, 1_200_000, 1_500_000 ].sample
        loan_value = (home_value * 0.6).to_i
        {
          user: user,
          application: {
            id: rand(1000..9999),
            reference_number: sprintf("%06d", rand(1000..999_999)),
            address: "123 Collins Street, Melbourne VIC 3000",
            home_value: home_value,
            formatted_home_value: currency(home_value),
            existing_mortgage_amount: (home_value * 0.2).to_i,
            formatted_existing_mortgage_amount: currency((home_value * 0.2).to_i),
            loan_value: loan_value,
            formatted_loan_value: currency(loan_value),
            borrower_age: rand(60..75),
            loan_term: [ 10, 15, 20, 25 ].sample,
            growth_rate: 3.5,
            formatted_growth_rate: "3.5%",
            future_property_value: (home_value * 1.5).to_i,
            formatted_future_property_value: currency((home_value * 1.5).to_i),
            home_equity_preserved: (home_value * 0.7).to_i,
            formatted_home_equity_preserved: currency((home_value * 0.7).to_i),
            status: "submitted",
            status_display: "Submitted for Review",
            created_at: 2.days.ago,
            updated_at: 3.hours.ago,
            submitted_at: 3.hours.ago,
            formatted_created_at: 2.days.ago.strftime("%B %d, %Y at %I:%M %p"),
            formatted_updated_at: 3.hours.ago.strftime("%B %d, %Y at %I:%M %p"),
            formatted_submitted_at: 3.hours.ago.strftime("%B %d, %Y at %I:%M %p")
          },
          mortgage: {
            name: "Premium Equity Mortgage",
            lvr: "60",
            interest_rate: EpmModelConfig.indicative_borrower_rate_pct.to_s,
            mortgage_type_display: "Equity Preservation"
          }
        }
      when "security_notification"
        { user: user,
          security: { browser_info: "Chrome 120.0 on Windows 10",
                      ip_address: "203.0.113.#{rand(1..254)}",
                      location: "Sydney, Australia",
                      sign_in_time: 10.minutes.ago.strftime("%B %d, %Y at %I:%M %p") } }
      else
        { user: user }
      end
    end

    private

    def sample_application(user, mortgage)
      OpenStruct.new(
        id: 123, user: user, mortgage: mortgage || sample_mortgage,
        address: "123 Sample Street, Melbourne VIC 3000",
        home_value: 800_000, existing_mortgage_amount: 200_000,
        loan_term: 15, borrower_age: 65, growth_rate: 3.5,
        status: "submitted", status_display: "Submitted",
        created_at: 2.days.ago, updated_at: 1.day.ago, submitted_at: 1.day.ago,
        formatted_home_value: "$800,000",
        formatted_existing_mortgage_amount: "$200,000",
        formatted_loan_value: "$360,000",
        formatted_growth_rate: "3.50%",
        formatted_future_property_value: "$1,200,000",
        formatted_home_equity_preserved: "$840,000",
        formatted_created_at: 2.days.ago.strftime("%B %d, %Y at %I:%M %p"),
        formatted_updated_at: 1.day.ago.strftime("%B %d, %Y at %I:%M %p"),
        formatted_submitted_at: 1.day.ago.strftime("%B %d, %Y at %I:%M %p"),
        loan_value: 360_000, future_property_value: 1_200_000, home_equity_preserved: 840_000
      )
    end

    def sample_mortgage
      OpenStruct.new(
        id: 1, name: "Premium Equity Preservation Mortgage®", lvr: "60",
        interest_rate: EpmModelConfig.indicative_borrower_rate_pct.to_s,
        mortgage_type_display: "Equity Preservation"
      )
    end

    def currency(number)
      "$#{number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
  end
end
