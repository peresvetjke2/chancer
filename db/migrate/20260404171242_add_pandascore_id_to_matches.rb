class AddPandascoreIdToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :pandascore_id, :integer
    add_index :matches, :pandascore_id, unique: true
  end
end
