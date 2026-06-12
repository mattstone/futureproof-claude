require "test_helper"

class AdminDailyDigestJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "sends the digest to futureproof admins" do
    fp_admins = User.where(admin: true).joins(:lender).where(lenders: { lender_type: :futureproof }).count
    assert fp_admins.positive?, "fixture sanity: need at least one FP admin"

    assert_emails fp_admins do
      AdminDailyDigestJob.perform_now
    end
  end

  test "digest mail contains counts and dashboard link" do
    mail = AdminMailer.daily_attention_digest(
      to: "admin@example.com",
      recommendations: AdminManagementAttentionService.new.call,
      counts: { open_tickets: 2, applications_awaiting: 3, open_change_requests: 1 }
    )
    assert_match(/6 items need attention/, mail.subject)
    assert_match(/admin\/dashboard/, mail.body.encoded)
  end
end
