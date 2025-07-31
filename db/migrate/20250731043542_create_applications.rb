class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address
      t.integer :home_value

      t.timestamps
    end
  end
end
