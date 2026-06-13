class StandardizeCountryCodes < ActiveRecord::Migration[8.1]
  def change
    # Standardize Application region field to uppercase ISO codes
    reversible do |dir|
      dir.up do
        # Convert lowercase/mixed case to uppercase
        execute <<-SQL
          UPDATE applications#{' '}
          SET region = UPPER(region)#{' '}
          WHERE region IS NOT NULL AND region != UPPER(region);
        SQL

        # Change default from 'us' to 'US'
        change_column_default :applications, :region, from: "us", to: "US"

        # Standardize Lender country field to uppercase
        execute <<-SQL
          UPDATE lenders#{' '}
          SET country = UPPER(country)#{' '}
          WHERE country IS NOT NULL AND country != UPPER(country);
        SQL
      end

      dir.down do
        change_column_default :applications, :region, from: "US", to: "us"

        execute <<-SQL
          UPDATE applications#{' '}
          SET region = LOWER(region)#{' '}
          WHERE region IS NOT NULL;
        SQL

        execute <<-SQL
          UPDATE lenders#{' '}
          SET country = LOWER(country)#{' '}
          WHERE country IS NOT NULL;
        SQL
      end
    end
  end
end
