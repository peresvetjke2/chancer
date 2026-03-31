class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.datetime :played_at
      t.string :tournament
      t.string :score
      t.bigint :team1_id, null: false
      t.bigint :team2_id, null: false
      t.bigint :winner_id

      t.timestamps
    end

    add_index :matches, :team1_id
    add_index :matches, :team2_id
    add_index :matches, :winner_id
    add_foreign_key :matches, :teams, column: :team1_id
    add_foreign_key :matches, :teams, column: :team2_id
    add_foreign_key :matches, :teams, column: :winner_id
  end
end
