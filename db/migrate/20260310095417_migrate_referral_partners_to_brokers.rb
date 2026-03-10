class MigrateReferralPartnersToBrokers < ActiveRecord::Migration[8.1]
  def up
    # Create brokers from referral partners
    execute <<-SQL
      INSERT INTO brokers (name, email, jurisdiction, phone, encrypted_password, active, created_at, updated_at)
      SELECT 
        rp.name,
        rp.contact_email,
        CASE rp.region
          WHEN 'au' THEN 'AU'
          WHEN 'us' THEN 'US'
          WHEN 'nz' THEN 'NZ'
          WHEN 'uk' THEN 'UK'
          ELSE 'AU'
        END,
        NULL,
        '',
        CASE rp.status WHEN 'active' THEN true ELSE false END,
        rp.created_at,
        rp.updated_at
      FROM referral_partners rp
      ON CONFLICT DO NOTHING;
    SQL

    # Create broker_lenders associations
    execute <<-SQL
      INSERT INTO broker_lenders (broker_id, lender_id, active, created_at, updated_at)
      SELECT 
        b.id,
        rp.lender_id,
        CASE rp.status WHEN 'active' THEN true ELSE false END,
        rp.created_at,
        rp.updated_at
      FROM referral_partners rp
      JOIN brokers b ON b.name = rp.name
      ON CONFLICT DO NOTHING;
    SQL

    # Create broker_commission_rates from referral partner commission rates
    execute <<-SQL
      INSERT INTO broker_commission_rates (broker_id, lender_id, commission_percentage, payment_trigger, active, created_at, updated_at)
      SELECT 
        b.id,
        rp.lender_id,
        rp.commission_rate,
        'on_approval',
        CASE rp.status WHEN 'active' THEN true ELSE false END,
        rp.created_at,
        rp.updated_at
      FROM referral_partners rp
      JOIN brokers b ON b.name = rp.name
      WHERE rp.commission_rate IS NOT NULL
      ON CONFLICT DO NOTHING;
    SQL

    # Migrate applications from referral_partner_id to broker_id
    execute <<-SQL
      UPDATE applications
      SET broker_id = b.id
      FROM referral_partners rp
      JOIN brokers b ON b.name = rp.name
      WHERE applications.referral_partner_id = rp.id;
    SQL

    # Drop the old referral_partner_id column
    remove_column :applications, :referral_partner_id
  end

  def down
    # Restore referral_partner_id column
    add_column :applications, :referral_partner_id, :bigint
    add_foreign_key :applications, :referral_partners

    # Migrate back from broker_id to referral_partner_id
    execute <<-SQL
      UPDATE applications a
      SET referral_partner_id = rp.id
      FROM brokers b
      JOIN referral_partners rp ON rp.name = b.name
      WHERE a.broker_id = b.id;
    SQL

    # Delete created brokers/associations/rates (keep original referral partners)
    execute <<-SQL
      DELETE FROM broker_commission_rates
      WHERE broker_id IN (
        SELECT b.id FROM brokers b
        WHERE EXISTS (SELECT 1 FROM referral_partners rp WHERE rp.name = b.name)
      );
    SQL

    execute <<-SQL
      DELETE FROM broker_lenders
      WHERE broker_id IN (
        SELECT b.id FROM brokers b
        WHERE EXISTS (SELECT 1 FROM referral_partners rp WHERE rp.name = b.name)
      );
    SQL

    execute <<-SQL
      DELETE FROM brokers
      WHERE name IN (SELECT name FROM referral_partners);
    SQL
  end
end
