class AddCreatedStatusToApplications < ActiveRecord::Migration[8.0]
  def up
    # Update all existing status values to shift them up by 1
    # This preserves the current status of all applications
    execute <<-SQL
      UPDATE applications SET status = status + 1;
    SQL
  end

  def down
    # Shift status values back down by 1
    execute <<-SQL
      UPDATE applications SET status = status - 1 WHERE status > 0;
    SQL
  end
end
