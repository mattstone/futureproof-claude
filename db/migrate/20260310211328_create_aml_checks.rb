class CreateAmlChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :aml_checks do |t|
      t.references :application, null: false, foreign_key: true
      t.integer :status
      t.string :risk_level
      t.datetime :checked_at
      t.datetime :passed_at
      t.text :failure_reason
      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end
