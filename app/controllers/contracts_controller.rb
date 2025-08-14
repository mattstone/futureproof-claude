class ContractsController < ApplicationController
  before_action :authenticate_user!, except: [:messages]
  before_action :verify_secure_token, only: [:messages], if: -> { params[:token].present? }
  before_action :authenticate_user!, only: [:messages], unless: -> { params[:token].present? }
  before_action :set_contract, only: [:show, :reply_to_message, :mark_all_messages_as_read]
  before_action :set_contract, only: [:messages], unless: -> { params[:token].present? }

  def show
    # Contract details page for customer
  end

  def messages
    # Show messages page for customer
    @messages = @contract.message_threads
    @new_message = @contract.contract_messages.build
    
    # If a specific message ID is provided (from email link), highlight it
    @highlight_message_id = params[:message_id]&.to_i
    
    # Mark admin messages as read when customer views them
    @contract.contract_messages.admin_messages.unread.update_all(
      status: 'read', 
      read_at: Time.current
    )
  end

  def reply_to_message
    # Customer replying to admin message
    @message = @contract.contract_messages.build(reply_params)
    @message.sender = current_user
    @message.message_type = 'customer_to_admin'
    @message.status = 'sent'
    @message.sent_at = Time.current
    
    # If replying to a specific message, mark the parent as replied
    if params[:parent_message_id].present?
      parent_message = @contract.contract_messages.find(params[:parent_message_id])
      parent_message.mark_as_replied!
      @message.parent_message = parent_message
    end
    
    respond_to do |format|
      if @message.save
        format.html { redirect_to messages_contract_path(@contract), notice: 'Your reply has been sent!' }
        format.turbo_stream { 
          flash.now[:notice] = 'Your reply has been sent!'
          render :reply_success 
        }
      else
        format.html { 
          @messages = @contract.message_threads
          @new_message = @message
          render :messages, status: :unprocessable_entity
        }
        format.turbo_stream { render :reply_error }
      end
    end
  end

  def mark_all_messages_as_read
    if @contract.application.user == current_user
      # Mark all admin messages as read for this contract
      @contract.contract_messages
               .where(message_type: 'admin_to_customer', status: 'sent')
               .update_all(status: 'read')
      
      # Get updated total unread count across all contracts for this user
      unread_count = Contract.joins(:application, :contract_messages)
        .where(applications: { user_id: current_user.id })
        .where(contract_messages: { message_type: 'admin_to_customer', status: 'sent' })
        .count('contract_messages.id')

      render json: { 
        success: true, 
        unread_count: unread_count,
        message: 'All contract messages marked as read' 
      }
    else
      render json: { success: false, error: 'Unauthorized' }, status: :forbidden
    end
  end

  private

  def set_contract
    @contract = current_user.applications.joins(:contract).find_by!(contracts: { id: params[:id] }).contract
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Contract not found.'
  end

  def reply_params
    params.require(:contract_message).permit(:subject, :content, :parent_message_id)
  end
  
  def verify_secure_token
    return unless params[:token].present?
    
    begin
      # Decrypt and verify the secure token
      payload = SecureTokenEncryptor.decrypt_and_verify(params[:token])
      
      # Check if token has expired
      if payload['expires_at'] < Time.current.to_i
        redirect_to new_user_session_path, alert: 'This link has expired. Please log in to access your messages.'
        return
      end
      
      # Verify the contract and user match, and that the token is for the requested contract
      contract = Contract.find_by(id: payload['contract_id'])
      user = User.find_by(id: payload['user_id'])
      requested_contract_id = params[:id].to_i
      
      unless contract && user && contract.application.user == user && contract.id == requested_contract_id
        redirect_to new_user_session_path, alert: 'Invalid access link. Please log in to continue.'
        return
      end
      
      # Store the intended redirect path in Rails cache (session gets reset on login)
      # Redirect to dashboard with contracts expanded instead of messages page
      intended_path = "#{dashboard_path}?section=contracts&contract_id=#{contract.id}"
      
      cache_key = "user_#{user.id}_pending_redirect"
      Rails.cache.write(cache_key, intended_path, expires_in: 10.minutes)
      
      redirect_to new_user_session_path, notice: 'Please log in to access your message.'
      
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_user_session_path, alert: 'Invalid access link. Please log in to continue.'
    end
  end
end