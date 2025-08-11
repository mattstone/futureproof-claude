require 'test_helper'

class Admin::ApplicationsControllerEditRestrictionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-edit-test@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @regular_user = User.create!(
      first_name: "Regular",
      last_name: "User",
      email: "user-edit-test@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @application = Application.create!(
      user: @regular_user,
      address: "123 Test Street, Portland, OR",
      home_value: 800000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )
    
    sign_in @admin
  end

  test "admin can update application status to allowed values" do
    # Test updating to processing
    patch admin_application_path(@application), params: {
      application: { status: 'processing' }
    }
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'Application status was successfully updated.', flash[:notice]
    assert_equal 'processing', @application.reload.status
    
    # Test updating to rejected with reason
    patch admin_application_path(@application), params: {
      application: { 
        status: 'rejected',
        rejected_reason: 'Application does not meet requirements'
      }
    }
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'rejected', @application.reload.status
    assert_equal 'Application does not meet requirements', @application.rejected_reason
    
    # Test updating to accepted
    patch admin_application_path(@application), params: {
      application: { status: 'accepted' }
    }
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'accepted', @application.reload.status
    assert_nil @application.reload.rejected_reason # Should be cleared when not rejected
  end

  test "admin cannot update application status to disallowed values" do
    original_status = @application.status
    
    # Try to update to a disallowed status
    patch admin_application_path(@application), params: {
      application: { status: 'created' }
    }
    
    # Should still redirect but status should not change
    assert_redirected_to admin_application_path(@application)
    assert_equal original_status, @application.reload.status
  end

  test "admin cannot update other application fields" do
    original_address = @application.address
    original_home_value = @application.home_value
    original_user_id = @application.user_id
    
    # Try to update other fields along with status
    patch admin_application_path(@application), params: {
      application: { 
        status: 'processing',
        address: 'Hacked Address',
        home_value: 999999,
        user_id: @admin.id
      }
    }
    
    assert_redirected_to admin_application_path(@application)
    @application.reload
    
    # Status should be updated (allowed)
    assert_equal 'processing', @application.status
    
    # Other fields should remain unchanged (not allowed)
    assert_equal original_address, @application.address
    assert_equal original_home_value, @application.home_value
    assert_equal original_user_id, @application.user_id
  end

  test "rejected reason validation works correctly" do
    # Try to reject without providing a reason
    patch admin_application_path(@application), params: {
      application: { 
        status: 'rejected',
        rejected_reason: ''
      }
    }
    
    assert_response :unprocessable_entity
    assert_not_equal 'rejected', @application.reload.status
  end

  test "rejected reason is cleared when status changes from rejected" do
    # First set to rejected with reason
    @application.update!(status: 'rejected', rejected_reason: 'Test reason')
    
    # Then change to accepted
    patch admin_application_path(@application), params: {
      application: { status: 'accepted' }
    }
    
    assert_redirected_to admin_application_path(@application)
    @application.reload
    assert_equal 'accepted', @application.status
    assert_nil @application.rejected_reason
  end

  test "edit page shows application details as read-only" do
    get edit_admin_application_path(@application)
    
    assert_response :success
    
    # Should show application details
    assert_select '.application-details'
    assert_select '.detail-row', minimum: 5
    
    # Should show status update form
    assert_select '.status-update-section'
    assert_select 'select[name="application[status]"]'
    assert_select 'option[value="processing"]', text: 'Processing'
    assert_select 'option[value="rejected"]', text: 'Rejected'
    assert_select 'option[value="accepted"]', text: 'Accepted'
    
    # Should not show other editable fields
    assert_select 'input[name="application[address]"]', count: 0
    assert_select 'input[name="application[home_value]"]', count: 0
    assert_select 'select[name="application[user_id]"]', count: 0
  end

  test "edit page shows rejected reason field when status is rejected" do
    @application.update!(status: 'rejected', rejected_reason: 'Test rejection reason')
    
    get edit_admin_application_path(@application)
    
    assert_response :success
    assert_select 'textarea[name="application[rejected_reason]"]'
    assert_select '.rejected-reason-field'
  end

  test "edit page hides rejected reason field for other statuses" do
    @application.update!(status: 'processing')
    
    get edit_admin_application_path(@application)
    
    assert_response :success
    assert_select '.rejected-reason-field[style*="display: none"]'
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password123'
      }
    }
  end
end