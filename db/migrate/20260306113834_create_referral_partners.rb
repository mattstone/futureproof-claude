class CreateReferralPartners < ActiveRecord::Migration[8.1]
  def change
    create_table :referral_partners do |t|
      t.string :name, null: false
      t.string :company
      t.string :licence_number, null: false
      t.string :region, null: false
      t.decimal :commission_rate, precision: 5, scale: 2, default: 0.0
      t.string :status, default: "active"
      t.string :contact_email
      t.string :phone
      t.references :lender, null: false, foreign_key: true

      t.timestamps
    end

    add_index :referral_partners, :region
    add_index :referral_partners, :status
    add_index :referral_partners, :licence_number

    add_reference :applications, :referral_partner, foreign_key: true
  end
end
