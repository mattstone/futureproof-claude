class CreateMortgages < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgages do |t|
      t.text :name
      t.integer :mortgage_type

      t.timestamps
    end
  end
end
