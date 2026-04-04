class AddPandascoreFieldsToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :pandascore_id, :integer
    add_column :teams, :pandascore_rank, :integer
    add_index :teams, :pandascore_id, unique: true
  end
end
