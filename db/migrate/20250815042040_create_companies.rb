class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.integer :company_type, null: false
      t.string :name, null: false
      t.text :address
      t.string :postcode
      t.string :country, null: false, default: 'Australia'
      t.string :contact_email, null: false
      t.string :contact_telephone

      t.timestamps
    end
    
    add_index :companies, :company_type
    add_index :companies, :name
  end
end
