require 'test_helper'

class Admin::ContractMessagingTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts, :ai_agents

  def setup
    @admin = users(:admin_user)
    sign_in @admin
    
    # Create a contract for testing
    @contract = contracts(:basic_contract)
  end

  test "admin can view contract messaging interface" do
    get admin_contract_path(@contract)
    assert_response :success
    
    # Should show messaging form
    assert_select 'form[action=?]', create_message_admin_contract_path(@contract)
    assert_select 'input[name="contract_message[subject]"]'
    assert_select 'textarea[name="contract_message[content]"]'
    assert_select 'select[name="contract_message[ai_agent_id]"]'
  end

  test "admin can create and send contract message" do
    assert_difference 'ContractMessage.count', 1 do
      post create_message_admin_contract_path(@contract), params: {
        contract_message: {
          subject: "Contract Status Update",
          content: "Hello {{user.first_name}}, your contract status is {{contract.status_display}}.",
          ai_agent_id: ai_agents(:customer_success_manager).id
        },
        send_now: true
      }
    end
    
    assert_redirected_to admin_contract_path(@contract)
    follow_redirect!
    assert_match "Message sent successfully!", response.body
    
    message = ContractMessage.last
    assert_equal @contract, message.contract
    assert_equal @admin, message.sender
    assert_equal 'admin_to_customer', message.message_type
    assert_equal 'sent', message.status
    assert_equal ai_agents(:customer_success_manager), message.ai_agent
  end

  test "admin can save contract message as draft" do
    assert_difference 'ContractMessage.count', 1 do
      post create_message_admin_contract_path(@contract), params: {
        contract_message: {
          subject: "Draft Message",
          content: "This is a draft message about {{contract.status_display}}.",
          ai_agent_id: ai_agents(:customer_success_manager).id
        },
        save_draft: true
      }
    end
    
    assert_redirected_to admin_contract_path(@contract)
    follow_redirect!
    assert_match "Message saved as draft!", response.body
    
    message = ContractMessage.last
    assert_equal 'draft', message.status
    assert_nil message.sent_at
  end

  test "contract message processes template variables correctly" do
    message = ContractMessage.create!(
      contract: @contract,
      sender: @admin,
      message_type: 'admin_to_customer',
      subject: "Update for {{user.first_name}}",
      content: "Your contract {{contract.id}} is {{contract.status_display}}. Property: {{application.address}}",
      status: 'draft',
      ai_agent: ai_agents(:customer_success_manager)
    )
    
    processed_subject = message.processed_subject
    processed_content_html = message.content_html
    
    # Should replace template variables
    assert_includes processed_subject, @contract.application.user.first_name
    assert_includes processed_content_html.to_s, @contract.id.to_s
    assert_includes processed_content_html.to_s, @contract.status.humanize
    assert_includes processed_content_html.to_s, @contract.application.address
  end

  test "contract shows message indicators in admin index" do
    # Create some test messages
    ContractMessage.create!(
      contract: @contract,
      sender: @admin,
      message_type: 'admin_to_customer',
      subject: "Test Message",
      content: "Test content",
      status: 'sent',
      ai_agent: ai_agents(:customer_success_manager)
    )
    
    ContractMessage.create!(
      contract: @contract,
      sender: @contract.application.user,
      message_type: 'customer_to_admin',
      subject: "Customer Reply",
      content: "Customer response",
      status: 'sent'
    )
    
    get admin_contracts_path
    assert_response :success
    
    # Should show message indicators
    assert_select '.message-indicators'
    assert_select '.message-indicator'
  end

  test "contract messaging helpers work correctly" do
    # Clear any existing customer messages for this contract
    @contract.contract_messages.customer_messages.destroy_all
    
    # Create unread customer message
    customer_message = ContractMessage.create!(
      contract: @contract,
      sender: @contract.application.user,
      message_type: 'customer_to_admin',
      subject: "Customer Question",
      content: "I have a question",
      status: 'sent'
    )
    
    assert @contract.has_unread_customer_messages?
    assert_equal 1, @contract.unread_customer_messages_count
    assert_equal customer_message, @contract.latest_customer_message
    
    # Mark as read
    customer_message.mark_as_read!
    assert_not @contract.reload.has_unread_customer_messages?
    assert_equal 0, @contract.unread_customer_messages_count
  end

  test "contract message validation works" do
    message = ContractMessage.new(
      contract: @contract,
      sender: @admin,
      message_type: 'admin_to_customer'
    )
    
    assert_not message.valid?
    assert_includes message.errors[:subject], "can't be blank"
    assert_includes message.errors[:content], "can't be blank"
    assert_includes message.errors[:status], "can't be blank"
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end