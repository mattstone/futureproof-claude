class CreateMortgageLenders < ActiveRecord::Migration[8.0]
  def up
    # Create the join table
    create_table :mortgage_lenders do |t|
      t.references :mortgage, null: false, foreign_key: true
      t.references :lender, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :mortgage_lenders, :active
    add_index :mortgage_lenders, [:mortgage_id, :lender_id], unique: true
    add_index :mortgage_lenders, [:lender_id, :mortgage_id]
    
    # Migrate existing data from mortgages.lender_id to the join table
    execute <<-SQL
      INSERT INTO mortgage_lenders (mortgage_id, lender_id, active, created_at, updated_at)
      SELECT id, lender_id, true, created_at, updated_at
      FROM mortgages
      WHERE lender_id IS NOT NULL
    SQL
    
    # Remove the old lender_id column from mortgages
    remove_foreign_key :mortgages, :lenders if foreign_key_exists?(:mortgages, :lenders)
    remove_index :mortgages, :lender_id if index_exists?(:mortgages, :lender_id)
    remove_column :mortgages, :lender_id
  end

  def down
    # Add back the lender_id column
    add_reference :mortgages, :lender, foreign_key: true
    
    # Migrate data back (only taking the first active lender for each mortgage)
    execute <<-SQL
      UPDATE mortgages 
      SET lender_id = (
        SELECT lender_id 
        FROM mortgage_lenders 
        WHERE mortgage_lenders.mortgage_id = mortgages.id 
        AND active = true 
        LIMIT 1
      )
    SQL
    
    # Drop the join table
    drop_table :mortgage_lenders
  end
end
