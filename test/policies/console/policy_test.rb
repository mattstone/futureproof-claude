require "test_helper"

class Console::PolicyTest < ActiveSupport::TestCase
  test "futureproof admin has every capability" do
    policy = Console::Policy.new(users(:admin_user))

    assert policy.access?
    assert policy.futureproof?
    assert_not policy.lender?
    Console::Policy::CAPABILITIES.each do |capability|
      assert policy.can?(capability), "expected futureproof admin to have #{capability}"
    end
  end

  test "lender admin works the pipeline but cannot shape the platform" do
    policy = Console::Policy.new(users(:lender_admin_user))

    assert policy.access?
    assert policy.lender?
    assert_not policy.futureproof?
    assert_equal lenders(:broker), policy.lender

    assert policy.can?(:view_pipeline)
    assert policy.can?(:manage_users)

    %i[manage_partners manage_product publish_prompts view_system run_diagnostics].each do |capability|
      assert_not policy.can?(capability), "expected lender admin to lack #{capability}"
    end
  end

  test "non-admin user has no access and no capabilities" do
    policy = Console::Policy.new(users(:regular_user))

    assert_not policy.access?
    Console::Policy::CAPABILITIES.each do |capability|
      assert_not policy.can?(capability)
    end
  end

  test "nil user has no access" do
    policy = Console::Policy.new(nil)

    assert_not policy.access?
    assert_not policy.admin?
    assert_not policy.futureproof?
    assert_not policy.lender?
  end

  test "unknown capability raises rather than failing open" do
    policy = Console::Policy.new(users(:admin_user))

    assert_raises(ArgumentError) { policy.can?(:delete_everything) }
  end
end
