# Suspend/offboard support for partners: neither lenders nor wholesale
# funders had any lifecycle flag. Additive (default active for every
# existing row, NOT NULL) and trivially reversible.
class AddStatusToPartners < ActiveRecord::Migration[8.1]
  def change
    add_column :lenders, :status, :integer, default: 0, null: false
    add_column :wholesale_funders, :status, :integer, default: 0, null: false
  end
end
