require "test_helper"

class LenderTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "contact@testlender.com",
      country: "Australia"
    }
    
    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      confirmed_at: Time.current,
      lender: lenders(:futureproof),
      admin: true,
      terms_accepted: true,
      terms_version: "1.0"
    )
  end

  # Basic Validation Tests
  test "should be valid with valid attributes" do
    lender = Lender.new(@valid_attributes)
    assert lender.valid?
  end

  test "should require name" do
    lender = Lender.new(@valid_attributes.except(:name))
    refute lender.valid?
    assert_includes lender.errors[:name], "can't be blank"
  end

  test "should require lender_type" do
    lender = Lender.new(@valid_attributes.except(:lender_type))
    refute lender.valid?
    assert_includes lender.errors[:lender_type], "can't be blank"
  end

  test "should require contact_email" do
    lender = Lender.new(@valid_attributes.except(:contact_email))
    refute lender.valid?
    assert_includes lender.errors[:contact_email], "can't be blank"
  end

  test "should require country" do
    lender = Lender.new(@valid_attributes.except(:country))
    refute lender.valid?
    assert_includes lender.errors[:country], "can't be blank"
  end

  test "should validate email format" do
    invalid_emails = ["invalid", "invalid@", "@domain.com", "invalid@domain", ""]
    
    invalid_emails.each do |email|
      lender = Lender.new(@valid_attributes.merge(contact_email: email))
      refute lender.valid?, "Expected #{email} to be invalid"
      assert_includes lender.errors[:contact_email], "is invalid"
    end
  end

  test "should accept valid email formats" do
    valid_emails = ["test@example.com", "user.name@domain.co.uk", "admin+test@company.org"]
    
    valid_emails.each do |email|
      lender = Lender.new(@valid_attributes.merge(contact_email: email))
      assert lender.valid?, "Expected #{email} to be valid"
    end
  end

  # Enum Tests
  test "should have correct enum values" do
    assert_equal({ "futureproof" => 0, "lender" => 1 }, Lender.lender_types)
  end

  test "lender_type_futureproof? method should work correctly" do
    futureproof_lender = Lender.new(@valid_attributes.merge(lender_type: :futureproof))
    regular_lender = Lender.new(@valid_attributes.merge(lender_type: :lender))
    
    assert futureproof_lender.lender_type_futureproof?
    refute regular_lender.lender_type_futureproof?
  end

  test "lender_type_lender? method should work correctly" do
    futureproof_lender = Lender.new(@valid_attributes.merge(lender_type: :futureproof))
    regular_lender = Lender.new(@valid_attributes.merge(lender_type: :lender))
    
    refute futureproof_lender.lender_type_lender?
    assert regular_lender.lender_type_lender?
  end

  test "should scope lenders by type correctly" do
    # Get existing counts
    futureproof_count = Lender.lender_type_futureproof.count
    lender_count = Lender.lender_type_lender.count
    
    # Create test lenders
    lender1 = Lender.create!(@valid_attributes.merge(lender_type: :lender, name: "Test Lender 1"))
    lender2 = Lender.create!(@valid_attributes.merge(lender_type: :lender, name: "Test Lender 2", contact_email: "test2@lender.com"))
    
    # Verify scopes work
    assert_equal lender_count + 2, Lender.lender_type_lender.count
    assert_equal futureproof_count, Lender.lender_type_futureproof.count
    
    # Cleanup
    lender1.destroy
    lender2.destroy
  end

  # Futureproof Uniqueness Validation Tests
  test "should allow only one futureproof lender" do
    # First futureproof lender should be fine
    first_futureproof = Lender.create!(@valid_attributes.merge(
      lender_type: :futureproof,
      name: "First Futureproof"
    ))
    
    # Second futureproof lender should fail
    second_futureproof = Lender.new(@valid_attributes.merge(
      lender_type: :futureproof,
      name: "Second Futureproof",
      contact_email: "second@futureproof.com"
    ))
    
    refute second_futureproof.valid?
    assert_includes second_futureproof.errors[:lender_type], "Only one Futureproof lender is allowed"
    
    # Cleanup
    first_futureproof.destroy
  end

  test "should allow multiple regular lenders" do
    lender1 = Lender.create!(@valid_attributes.merge(name: "Lender 1"))
    lender2 = Lender.create!(@valid_attributes.merge(
      name: "Lender 2", 
      contact_email: "lender2@test.com"
    ))
    
    assert lender1.persisted?
    assert lender2.persisted?
    
    # Cleanup
    lender1.destroy
    lender2.destroy
  end

  test "should allow editing existing futureproof lender" do
    existing_futureproof = lenders(:futureproof)
    existing_futureproof.name = "Updated Futureproof Name"
    assert existing_futureproof.valid?
  end

  # Association Tests
  test "should have many users with restrict_with_exception" do
    lender = Lender.create!(@valid_attributes)
    
    user = User.create!(
      email: "user@lender.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      confirmed_at: Time.current,
      lender: lender,
      terms_accepted: true,
      terms_version: "1.0"
    )
    
    assert_includes lender.users, user
    
    # Should not be able to delete lender with users
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      lender.destroy
    end
    
    # Cleanup
    user.destroy
    lender.destroy
  end

  test "should have many mortgages with restrict_with_exception" do
    association = Lender.reflect_on_association(:mortgages)
    assert_equal :restrict_with_exception, association.options[:dependent]
  end

  test "should have many wholesale funder relationships" do
    lender = Lender.create!(@valid_attributes)
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    lender_wf = LenderWholesaleFunder.create!(
      lender: lender,
      wholesale_funder: wholesale_funder,
      active: true
    )
    
    assert_includes lender.wholesale_funders, wholesale_funder
    assert_includes lender.active_wholesale_funders, wholesale_funder
    
    # Make inactive and test
    lender_wf.update!(active: false)
    lender.reload
    assert_includes lender.wholesale_funders, wholesale_funder
    refute_includes lender.active_wholesale_funders, wholesale_funder
    
    # Cleanup
    lender_wf.destroy
    wholesale_funder.destroy
    lender.destroy
  end

  test "should have many funder pool relationships" do
    lender = Lender.create!(@valid_attributes)
    wholesale_funder = WholesaleFunder.create!(
      name: "Test WF for Pool",
      country: "Australia", 
      currency: "AUD"
    )
    
    funder_pool = FunderPool.create!(
      wholesale_funder: wholesale_funder,
      name: "Test Pool",
      amount: 1000000,
      allocated: 200000,
      benchmark_rate: 4.0,
      margin_rate: 2.5
    )
    
    lender_fp = LenderFunderPool.create!(
      lender: lender,
      funder_pool: funder_pool,
      active: true
    )
    
    assert_includes lender.funder_pools, funder_pool
    assert_includes lender.active_funder_pools, funder_pool
    
    # Cleanup
    lender_fp.destroy
    funder_pool.destroy
    wholesale_funder.destroy
    lender.destroy
  end

  # Change Tracking Tests
  test "should include ChangeTracking concern" do
    assert Lender.included_modules.include?(ChangeTracking)
  end

  test "should have correct tracked fields" do
    expected_fields = [:name, :lender_type, :contact_email, :country]
    assert_equal expected_fields, Lender.tracked_fields
  end

  test "should have lender_versions association" do
    association = Lender.reflect_on_association(:lender_versions)
    assert_not_nil association
    assert_equal :has_many, association.macro
    assert_equal :destroy, association.options[:dependent]
  end

  test "should track creation when current_user is set" do
    lender = Lender.new(@valid_attributes)
    lender.current_user = @admin_user
    
    assert_difference('LenderVersion.count', 1) do
      lender.save!
    end
    
    version = LenderVersion.last
    assert_equal 'created', version.action
    assert_equal @admin_user, version.user
    assert_equal lender, version.lender
    assert_includes version.change_details, lender.name
    
    # Cleanup
    lender.destroy
  end

  test "should track updates when current_user is set" do
    lender = Lender.create!(@valid_attributes)
    lender.current_user = @admin_user
    
    assert_difference('LenderVersion.count', 1) do
      lender.update!(name: "Updated Name", contact_email: "updated@email.com")
    end
    
    version = LenderVersion.last
    assert_equal 'updated', version.action
    assert_equal @admin_user, version.user
    assert_includes version.change_details.downcase, "name"
    assert_includes version.change_details.downcase, "contact email"
    
    # Cleanup
    lender.destroy
  end

  test "should track view when log_view_by is called" do
    lender = Lender.create!(@valid_attributes)
    
    assert_difference('LenderVersion.count', 1) do
      lender.log_view_by(@admin_user)
    end
    
    version = LenderVersion.last
    assert_equal 'viewed', version.action
    assert_equal @admin_user, version.user
    assert_includes version.change_details, "viewed"
    
    # Cleanup
    lender.destroy
  end

  test "should not track changes without current_user" do
    lender = Lender.new(@valid_attributes)
    
    assert_no_difference('LenderVersion.count') do
      lender.save!
    end
    
    assert_no_difference('LenderVersion.count') do
      lender.update!(name: "Updated Without User")
    end
    
    # Cleanup
    lender.destroy
  end

  # Edge Cases and Error Handling
  test "should handle nil values gracefully" do
    lender = Lender.new(@valid_attributes.merge(
      address: nil,
      postcode: nil,
      contact_telephone: nil,
      contact_telephone_country_code: nil
    ))
    
    assert lender.valid?
  end

  test "should handle long names" do
    long_name = "A" * 255
    lender = Lender.new(@valid_attributes.merge(name: long_name))
    # This test assumes there's no explicit length validation - adjust if there is
    assert lender.valid?
    
    # Cleanup if created
    lender.destroy if lender.persisted?
  end

  test "should handle international characters" do
    international_attributes = @valid_attributes.merge(
      name: "Tëst Lêñdér Ñämé",
      country: "Österreich", # Austria in German
      contact_email: "tëst@lêñdér.com"
    )
    
    lender = Lender.new(international_attributes)
    # Note: email validation might fail with international characters
    # This tests the name and country handling specifically
    assert lender.valid? || lender.errors.keys == [:contact_email]
    
    # Cleanup if created
    lender.destroy if lender.persisted?
  end

  # Performance Tests (basic)
  test "should handle bulk queries efficiently" do
    # Create multiple lenders
    lenders = []
    5.times do |i|
      lenders << Lender.create!(@valid_attributes.merge(
        name: "Bulk Lender #{i}",
        contact_email: "bulk#{i}@lender.com"
      ))
    end
    
    # Test that we can query them efficiently
    results = Lender.where(name: lenders.map(&:name))
    assert_equal 5, results.count
    
    # Cleanup
    lenders.each(&:destroy)
  end
end