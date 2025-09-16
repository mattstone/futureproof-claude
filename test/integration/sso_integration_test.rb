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

  test "available_omniauth_providers detects Azure when environment variables set" do
    original_client_id = ENV['AZURE_CLIENT_ID']
    original_client_secret = ENV['AZURE_CLIENT_SECRET']

    begin
      ENV['AZURE_CLIENT_ID'] = 'test-client-id'
      ENV['AZURE_CLIENT_SECRET'] = 'test-client-secret'

      assert_includes User.available_omniauth_providers, :azure_activedirectory_v2
    ensure
      ENV['AZURE_CLIENT_ID'] = original_client_id
      ENV['AZURE_CLIENT_SECRET'] = original_client_secret
    end
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

  test "login page shows SSO button when environment variables present" do
    original_client_id = ENV['AZURE_CLIENT_ID']
    original_client_secret = ENV['AZURE_CLIENT_SECRET']

    begin
      ENV['AZURE_CLIENT_ID'] = 'test-client-id'
      ENV['AZURE_CLIENT_SECRET'] = 'test-client-secret'

      get new_user_session_path
      assert_response :success
      assert_select 'a[href="/users/auth/azure_activedirectory_v2"]', text: /Sign in with Microsoft/
    ensure
      ENV['AZURE_CLIENT_ID'] = original_client_id
      ENV['AZURE_CLIENT_SECRET'] = original_client_secret
    end
  end
end