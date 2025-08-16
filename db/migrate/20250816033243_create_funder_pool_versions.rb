class CreateFunderPoolVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :funder_pool_versions do |t|
      t.references :funder_pool, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :change_details
      
      # Track specific fields for funder pools
      t.string :previous_name
      t.string :new_name
      t.decimal :previous_amount, precision: 15, scale: 2
      t.decimal :new_amount, precision: 15, scale: 2
      t.decimal :previous_allocated, precision: 15, scale: 2
      t.decimal :new_allocated, precision: 15, scale: 2
      t.decimal :previous_benchmark_rate, precision: 5, scale: 2
      t.decimal :new_benchmark_rate, precision: 5, scale: 2
      t.decimal :previous_margin_rate, precision: 5, scale: 2
      t.decimal :new_margin_rate, precision: 5, scale: 2
      
      t.timestamps
    end
    
    add_index :funder_pool_versions, [:funder_pool_id, :created_at]
    add_index :funder_pool_versions, :action
  end
end
