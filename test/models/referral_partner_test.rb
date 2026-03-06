require "test_helper"

class ReferralPartnerTest < ActiveSupport::TestCase
  setup do
    @lender = lenders(:futureproof)
    @partner = ReferralPartner.new(
      name: "Test Partner",
      company: "Test Co",
      licence_number: "BR-TEST-999",
      region: "au",
      commission_rate: 2.5,
      status: "active",
      contact_email: "test@example.com",
      phone: "+61 400 000 000",
      lender: @lender
    )
  end

  test "valid referral partner" do
    assert @partner.valid?, @partner.errors.full_messages.join(", ")
  end

  test "requires name" do
    @partner.name = nil
    assert_not @partner.valid?
    assert_includes @partner.errors[:name], "can't be blank"
  end

  test "requires region" do
    @partner.region = nil
    assert_not @partner.valid?
  end

  test "validates region inclusion" do
    @partner.region = "invalid"
    assert_not @partner.valid?
    assert_includes @partner.errors[:region], "is not included in the list"
  end

  test "requires licence_number" do
    @partner.licence_number = nil
    assert_not @partner.valid?
  end

  test "licence_number unique per region" do
    @partner.save!
    duplicate = @partner.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:licence_number], "has already been taken"
  end

  test "licence_number can repeat across regions" do
    @partner.save!
    other = @partner.dup
    other.region = "us"
    assert other.valid?
  end

  test "validates commission_rate range" do
    @partner.commission_rate = -1
    assert_not @partner.valid?

    @partner.commission_rate = 101
    assert_not @partner.valid?

    @partner.commission_rate = 50
    assert @partner.valid?, @partner.errors.full_messages.join(", ")
  end

  test "validates email format" do
    @partner.contact_email = "not-an-email"
    assert_not @partner.valid?
  end

  test "belongs to lender" do
    assert_respond_to @partner, :lender
  end

  test "has many applications" do
    assert_respond_to @partner, :applications
  end

  test "active scope" do
    active = referral_partners(:helen_chen)
    inactive = ReferralPartner.create!(
      name: "Inactive Partner", licence_number: "BR-INACTIVE-001",
      region: "nz", status: "inactive", lender: @lender
    )
    assert_includes ReferralPartner.active, active
    assert_not_includes ReferralPartner.active, inactive
  end
end
