class AddBrokerToApplications < ActiveRecord::Migration[8.0]
  def change
    add_reference :applications, :broker, null: true, foreign_key: true
  end
end
