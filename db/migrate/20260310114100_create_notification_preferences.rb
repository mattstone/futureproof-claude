class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :payment_email
      t.boolean :payment_sms
      t.boolean :message_email
    end
  end
end
