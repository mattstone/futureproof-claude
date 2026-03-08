class CreateWholesaleFunderContracts < ActiveRecord::Migration[8.1]
  def change
    create_table :wholesale_funder_contracts do |t|
      t.references :wholesale_funder, null: false, foreign_key: true
      t.string :jurisdiction, null: false  # AU, US, NZ, UK
      t.text :html_content, null: false    # Sample contract HTML
      t.string :party_type, null: false    # e.g., "Lender Agreement", "Broker Agreement"
      t.string :version, default: "1.0"
      
      t.timestamps
    end

    add_index :wholesale_funder_contracts, 
              [:wholesale_funder_id, :jurisdiction, :party_type], 
              unique: true, 
              name: 'index_wf_contracts_unique'
  end
end
