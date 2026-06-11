class AddJurisdictionToWebhooks < ActiveRecord::Migration[8.1]
  def change
    add_column :webhooks, :jurisdiction, :string
  end
end
