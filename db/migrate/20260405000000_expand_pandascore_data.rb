class ExpandPandascoreData < ActiveRecord::Migration[8.0]
  def change
    # teams
    add_column :teams, :acronym,   :string
    add_column :teams, :image_url, :string
    add_column :teams, :slug,      :string

    # matches
    add_column :matches, :begin_at,        :datetime
    add_column :matches, :end_at,          :datetime
    add_column :matches, :match_type,      :string
    add_column :matches, :status,          :string
    add_column :matches, :league_id,       :bigint
    add_column :matches, :league_name,     :string
    add_column :matches, :serie_id,        :bigint
    add_column :matches, :serie_name,      :string
    add_column :matches, :tournament_id,   :bigint
    add_column :matches, :tournament_name, :string

    # map_results
    add_column :map_results, :pandascore_id,  :integer
    add_column :map_results, :winner_team_id, :bigint
    add_foreign_key :map_results, :teams, column: :winner_team_id
    add_index :map_results, :pandascore_id, unique: true
    add_index :map_results, :winner_team_id

    # players
    add_column :players, :pandascore_id, :integer
    add_index :players, :pandascore_id, unique: true
  end
end
