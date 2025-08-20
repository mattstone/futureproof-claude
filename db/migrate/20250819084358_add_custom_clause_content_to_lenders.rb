class AddCustomClauseContentToLenders < ActiveRecord::Migration[8.0]
  def change
    add_column :lenders, :custom_clause_content, :text
  end
end
