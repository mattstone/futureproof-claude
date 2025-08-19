class AddStatusToMortgages < ActiveRecord::Migration[8.0]
  def change
    add_column :mortgages, :status, :integer, default: 0, null: false
    add_index :mortgages, :status
  end
end
