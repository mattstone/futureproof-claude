class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # Applications indexes (critical for filtering)
    add_index :applications, :broker_id, if_not_exists: true
    add_index :applications, :lender_id, if_not_exists: true
    add_index :applications, [ :lender_id, :status ], if_not_exists: true
    add_index :applications, [ :broker_id, :status ], if_not_exists: true

    # Broker Commissions indexes (period queries + status filtering)
    add_index :broker_commissions, :broker_id, if_not_exists: true
    add_index :broker_commissions, :application_id, if_not_exists: true
    add_index :broker_commissions, :status, if_not_exists: true
    add_index :broker_commissions, [ :broker_id, :earned_date ], if_not_exists: true
    add_index :broker_commissions, [ :broker_id, :status ], if_not_exists: true

    # Broker Commission Rates indexes
    add_index :broker_commission_rates, [ :broker_id, :lender_id ], unique: true, if_not_exists: true
    add_index :broker_commission_rates, :lender_id, if_not_exists: true

    # Broker Lenders indexes
    add_index :broker_lenders, [ :broker_id, :lender_id ], unique: true, if_not_exists: true
    add_index :broker_lenders, :lender_id, if_not_exists: true

    # Distribution indexes (for payment processing queries)
    add_index :distributions, :application_id, if_not_exists: true
    add_index :distributions, [ :application_id, :status ], if_not_exists: true
  end
end
