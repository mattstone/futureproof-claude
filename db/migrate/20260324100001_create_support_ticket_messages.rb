class CreateSupportTicketMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :support_ticket_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.string :sender_type, null: false # customer, agent, system, ai_draft
      t.string :sender_email
      t.string :sender_name
      t.references :agent_user, foreign_key: { to_table: :users }, null: true
      t.text :body_text
      t.text :body_html
      t.string :microsoft_graph_message_id
      t.datetime :email_sent_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :support_ticket_messages, :sender_type
    add_index :support_ticket_messages, :microsoft_graph_message_id, unique: true
  end
end
