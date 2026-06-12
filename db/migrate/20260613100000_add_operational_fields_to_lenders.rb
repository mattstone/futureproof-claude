# Completes the lender record per the constituent spec
# (docs/prompts/constituents/lenders.md: a lender must hold the
# jurisdiction's licence) and basic operations (a named counterparty
# contact). Additive only; all columns nullable, so every existing row is
# untouched.
class AddOperationalFieldsToLenders < ActiveRecord::Migration[8.1]
  def change
    add_column :lenders, :contact_name, :string
    add_column :lenders, :licence_ref, :string
  end
end
