class AddHltvFieldsToTeams < ActiveRecord::Migration[8.1]
  def change
    rename_column :teams, :rating, :hltv_rank
    add_column :teams, :hltv_id, :integer
    add_index :teams, :hltv_id, unique: true
  end
end
