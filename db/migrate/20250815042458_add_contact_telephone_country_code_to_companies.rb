class AddContactTelephoneCountryCodeToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :contact_telephone_country_code, :string, default: '+61'
  end
end
