# Completes the broker record per the constituent spec
# (docs/prompts/constituents/brokers.md): firm_name, accreditation_ref, and
# the pending → active → suspended status workflow that replaces the bare
# active boolean. The boolean column stays (old admin and the lender portal
# read it) and is kept in sync by the model. Additive only.
class EnrichBrokers < ActiveRecord::Migration[8.1]
  # Lightweight class so the backfill is visible inside test transactions
  # (select_all/execute write outside them — lesson from the legal migration).
  class MigrationBroker < ActiveRecord::Base
    self.table_name = "brokers"
  end

  def up
    add_column :brokers, :firm_name, :string
    add_column :brokers, :accreditation_ref, :string
    add_column :brokers, :status, :integer, default: 1, null: false # active

    MigrationBroker.reset_column_information
    MigrationBroker.where(active: false).update_all(status: 2) # suspended
  end

  def down
    remove_column :brokers, :firm_name
    remove_column :brokers, :accreditation_ref
    remove_column :brokers, :status
  end
end
