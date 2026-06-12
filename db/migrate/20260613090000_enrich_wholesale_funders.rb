# Completes the wholesale funder record per the constituent spec
# (docs/prompts/constituents/wholesale-funders.md: type + terms) and basic
# operations (a counterparty contact). Additive only; all columns nullable
# or defaulted, so every existing row is untouched semantically.
class EnrichWholesaleFunders < ActiveRecord::Migration[8.1]
  def change
    add_column :wholesale_funders, :funding_type, :integer, default: 0, null: false # wholesale
    add_column :wholesale_funders, :terms, :text
    add_column :wholesale_funders, :contact_name, :string
    add_column :wholesale_funders, :contact_email, :string
    add_column :wholesale_funders, :contact_phone, :string
  end
end
