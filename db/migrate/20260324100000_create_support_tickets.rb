class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :support_tickets do |t|
      t.string :ticket_number, null: false
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "normal"
      t.string :category, null: false, default: "general"
      t.string :subject, null: false
      t.string :sender_email, null: false
      t.string :sender_name
      t.string :source, default: "email"
      t.string :microsoft_graph_message_id
      t.string :microsoft_graph_conversation_id

      t.references :user, foreign_key: true, null: true
      t.references :application, foreign_key: true, null: true

      t.datetime :resolved_at
      t.datetime :closed_at

      # Future AI integration
      t.text :ai_draft_reply
      t.string :ai_suggested_category
      t.decimal :ai_confidence_score, precision: 5, scale: 4
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :support_tickets, :ticket_number, unique: true
    add_index :support_tickets, :sender_email
    add_index :support_tickets, :status
    add_index :support_tickets, :priority
    add_index :support_tickets, :microsoft_graph_message_id, unique: true
  end
end
