class CreateMapResults < ActiveRecord::Migration[8.1]
  def change
    create_table :map_results do |t|
      t.string :map_name
      t.string :score
      t.references :match, null: false, foreign_key: true

      t.timestamps
    end
  end
end
