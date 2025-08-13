class CreateContractMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_messages do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :sender, polymorphic: true, null: false
      t.string :message_type
      t.string :subject
      t.text :content
      t.string :status
      t.datetime :sent_at
      t.datetime :read_at
      t.references :parent_message, null: true, foreign_key: { to_table: :contract_messages }
      t.references :ai_agent, null: true, foreign_key: true

      t.timestamps
    end
  end
end
