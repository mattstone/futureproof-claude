class CreateLenderWholesaleFunders < ActiveRecord::Migration[8.0]
  def change
    create_table :lender_wholesale_funders do |t|
      t.references :lender, null: false, foreign_key: true
      t.references :wholesale_funder, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :lender_wholesale_funders, [:lender_id, :wholesale_funder_id], 
              unique: true, name: 'index_lender_wholesale_funders_uniqueness'
  end
end
