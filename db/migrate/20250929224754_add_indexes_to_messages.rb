class AddIndexesToMessages < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for application_messages
    add_index :application_messages, [:status, :message_type], name: 'index_application_messages_on_status_and_message_type'
    add_index :application_messages, [:application_id, :status], name: 'index_application_messages_on_application_id_and_status'

    # Add indexes for contract_messages
    add_index :contract_messages, [:status, :message_type], name: 'index_contract_messages_on_status_and_message_type'
    add_index :contract_messages, [:contract_id, :status], name: 'index_contract_messages_on_contract_id_and_status'
  end
end
