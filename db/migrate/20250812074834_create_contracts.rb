class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.belongs_to :application, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end
  end
end
