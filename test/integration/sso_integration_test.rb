require 'test_helper'

class SsoIntegrationTest < ActionDispatch::IntegrationTest
  test "login page loads without errors" do
    get new_user_session_path
    assert_response :success
    assert_select 'h1', text: 'Sign In'
  end

  test "user model available_omniauth_providers method works" do
    assert_respond_to User, :available_omniauth_providers
    assert_kind_of Array, User.available_omniauth_providers
  end

  test "available_omniauth_providers includes SAML" do
    assert_includes User.available_omniauth_providers, :saml
  end

  test "omniauth callback controller exists" do
    assert defined?(Users::OmniauthCallbacksController)
    controller = Users::OmniauthCallbacksController.new
    assert_respond_to controller, :saml
  end

  test "saml metadata endpoint works" do
    get '/saml/metadata'
    assert_response :success
    assert_match 'futureproof-financial-saml', response.body
    assert_match 'EntityDescriptor', response.body
  end

  test "saml auth initiation redirects when no lender found" do
    get '/users/auth/saml'
    assert_response :redirect
    assert_redirected_to '/users/sign_in'
  end

  test "login page shows SAML SSO button when SAML configured" do
    original_sso_url = ENV['MICROSOFT_SAML_SSO_URL']
    original_cert = ENV['MICROSOFT_SAML_CERT']

    begin
      ENV['MICROSOFT_SAML_SSO_URL'] = 'https://test.sso.url'
      ENV['MICROSOFT_SAML_CERT'] = 'test-cert'

      get new_user_session_path
      assert_response :success
      assert_select 'a[href="/users/auth/saml"]', text: /Sign in with SSO/
    ensure
      ENV['MICROSOFT_SAML_SSO_URL'] = original_sso_url
      ENV['MICROSOFT_SAML_CERT'] = original_cert
    end
  end

  test "tenant detection service correctly identifies admin domains" do
    # Production admin domains
    assert TenantDetectionService.admin_domain?('demo.futureproofinancial.co')
    assert TenantDetectionService.admin_domain?('futureproofinancial.co')

    # Development admin domains (localhost) - only in development environment
    # In test environment, localhost is not considered admin by default
    # This is correct behavior - test environment should not auto-grant admin

    # Non-admin domains
    refute TenantDetectionService.admin_domain?('other-domain.com')
  end

  test "SAML authentication flow creates admin user for admin domains" do
    # Ensure we have a lender
    lender = Lender.lender_type_futureproof.first
    assert lender, "Futureproof lender must exist for SSO testing"

    # Mock SAML auth response for admin user
    admin_auth = OmniAuth::AuthHash.new({
      provider: 'saml',
      uid: 'test-saml-uid-admin-123',
      info: {
        email: "saml.admin.test#{rand(10000)}@company.com",
        first_name: 'SAML',
        last_name: 'AdminUser',
        name: 'SAML AdminUser'
      },
      extra: {
        raw_info: {
          'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname' => ['SAML'],
          'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname' => ['AdminUser'],
          'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/displayname' => ['SAML AdminUser']
        }
      }
    })

    # Mock SAML auth response for non-admin user
    non_admin_auth = OmniAuth::AuthHash.new({
      provider: 'saml',
      uid: 'test-saml-uid-user-456',
      info: {
        email: "saml.user.test#{rand(10000)}@company.com",
        first_name: 'SAML',
        last_name: 'RegularUser',
        name: 'SAML RegularUser'
      }
    })

    # Test user creation from SSO for admin domain
    user = User.from_omniauth(admin_auth, lender, true) # is_admin_domain = true

    assert user.persisted?, "User should be created successfully"
    assert_equal admin_auth.info.email, user.email
    assert_equal 'saml', user.sso_provider
    assert_equal 'test-saml-uid-admin-123', user.sso_uid
    assert user.admin?, "User should have admin privileges on admin domain"
    assert user.confirmed?, "SSO users should be auto-confirmed"
    assert_equal lender, user.lender

    # Test user creation for non-admin domain
    non_admin_user = User.from_omniauth(non_admin_auth, lender, false) # is_admin_domain = false
    refute non_admin_user.admin?, "User should not have admin privileges on non-admin domain"

    # Cleanup
    user.destroy
    non_admin_user.destroy
  end

  test "SAML authentication links existing user account" do
    lender = Lender.lender_type_futureproof.first
    assert lender, "Futureproof lender must exist for SSO testing"

    # Create existing user with unique email
    existing_email = "existing#{rand(10000)}@company.com"
    existing_user = User.create!(
      email: existing_email,
      first_name: 'Existing',
      last_name: 'User',
      lender: lender,
      admin: false,
      confirmed_at: Time.current,
      country_of_residence: 'United States',
      terms_accepted: true,
      terms_version: TermsOfUse.current&.version || TermsOfUse.last&.version || 1,
      password: 'password123'
    )

    # Mock SAML auth for same email
    mock_auth = OmniAuth::AuthHash.new({
      provider: 'saml',
      uid: 'existing-user-uid',
      info: {
        email: existing_email,
        first_name: 'Updated',
        last_name: 'Name'
      }
    })

    # Test linking existing account
    user = User.from_omniauth(mock_auth, lender, true)

    assert_equal existing_user.id, user.id, "Should link to existing user"
    assert_equal 'saml', user.sso_provider
    assert_equal 'existing-user-uid', user.sso_uid
    assert user.admin?, "Should gain admin privileges when linking on admin domain"

    # Cleanup
    user.destroy
  end
end