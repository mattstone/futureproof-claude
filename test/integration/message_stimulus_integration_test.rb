require 'test_helper'

class MessageStimulusIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email: 'test.stimulus@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: false,
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )

    @application = Application.create!(
      user: @user,
      address: "123 Test Street, Sydney NSW 2000",
      home_value: 800000,
      status: 'submitted',
      borrower_age: 65,
      loan_term: 15,
      existing_mortgage_amount: 0,
      has_existing_mortgage: false
    )

    # Create message
    @ai_agent = AiAgent.find_or_create_by(name: 'Motoko') do |agent|
      agent.role_description = 'AI Financial Assistant'
      agent.avatar_filename = 'Motoko.png'
      agent.active = true
    end

    @message = ApplicationMessage.create!(
      application: @application,
      sender: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Welcome to Futureproof',
      content: 'Thank you for your application submission.',
      status: 'sent',
      sent_at: 1.hour.ago
    )

    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
  end

  test "dashboard includes application messages Stimulus controller" do
    get dashboard_index_path
    assert_response :success
    
    # Should have Stimulus controller
    assert_select "[data-controller='application-messages']"
    assert_select "[data-application-messages-application-id-value='#{@application.id}']"
  end

  test "application messages view includes Stimulus controller for scrolling" do
    get messages_application_path(@application, highlight_message_id: @message.id)
    assert_response :success
    
    # Should have Stimulus controller with highlight value
    assert_select "[data-controller='application-messages']"
    assert_select "[data-application-messages-highlight-message-id-value='#{@message.id}']"
  end

  test "dashboard toggle buttons use Stimulus actions" do
    get dashboard_index_path
    assert_response :success
    
    # Toggle details button
    assert_select "button[data-action*='application-messages#toggleDetails'][data-application-id='#{@application.id}']"
    
    # Toggle messages button  
    assert_select "button[data-action*='application-messages#toggleMessages'][data-application-id='#{@application.id}']"
  end

  test "message action buttons use Stimulus actions" do
    get dashboard_index_path
    assert_response :success
    
    # Reply button
    assert_select "button[data-action*='application-messages#showReplyForm'][data-message-id='#{@message.id}']"
    
    # Mark as read button
    assert_select "button[data-action*='application-messages#markAsRead'][data-message-id='#{@message.id}']"
  end

  test "reply form cancel button uses Stimulus action" do
    get dashboard_index_path
    assert_response :success
    
    # Cancel button in reply form
    assert_select "button[data-action*='application-messages#hideReplyForm'][data-message-id='#{@message.id}']"
  end

  test "Stimulus controller is loaded in importmap" do
    get dashboard_index_path
    assert_response :success
    
    # Should include the controller in importmap
    assert_match /application_messages_controller/, response.body
  end
end