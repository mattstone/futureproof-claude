class CreateBrokerLenders < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_lenders do |t|
      t.references :broker, null: false, foreign_key: true
      t.references :lender, null: false, foreign_key: true
      t.integer :access_level
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :broker_lenders, [ :broker_id, :lender_id ], unique: true
  end
end
