class AddStatusAndRejectedReasonToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :status, :integer, default: 0, null: false
    add_column :applications, :rejected_reason, :text
  end
end
