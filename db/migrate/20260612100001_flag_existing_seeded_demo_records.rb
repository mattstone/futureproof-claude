# Marks the records created by db/seeds/business_demo.rb as demo data so
# dashboards and metrics can exclude them. Identified by the seed's fixed
# names — no real funder shares them. Reversible: clears the flags.
class FlagExistingSeededDemoRecords < ActiveRecord::Migration[8.1]
  SEED_FUNDERS = ["Macquarie Capital", "Blackrock Investments", "IFM Investors"].freeze
  SEED_POOLS = [
    "Macquarie Growth Fund I", "Macquarie Income Fund II", "Blackrock Global Alpha",
    "Blackrock Fixed Income", "IFM Australian Mortgage Trust"
  ].freeze

  def up
    funder_ids = exec_ids("SELECT id FROM wholesale_funders WHERE name IN (#{quoted(SEED_FUNDERS)})")
    pool_ids = exec_ids("SELECT id FROM funder_pools WHERE name IN (#{quoted(SEED_POOLS)})")

    execute "UPDATE wholesale_funders SET demo = TRUE WHERE id IN (#{funder_ids.join(',')})" if funder_ids.any?
    execute "UPDATE funder_pools SET demo = TRUE WHERE id IN (#{pool_ids.join(',')})" if pool_ids.any?
    execute "UPDATE contracts SET demo = TRUE WHERE funder_pool_id IN (#{pool_ids.join(',')})" if pool_ids.any?
  end

  def down
    execute "UPDATE contracts SET demo = FALSE"
    execute "UPDATE funder_pools SET demo = FALSE"
    execute "UPDATE wholesale_funders SET demo = FALSE"
  end

  private

  def quoted(names)
    names.map { |n| ActiveRecord::Base.connection.quote(n) }.join(",")
  end

  def exec_ids(sql)
    ActiveRecord::Base.connection.select_values(sql)
  end
end
