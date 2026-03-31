class CreateNewsItems < ActiveRecord::Migration[8.1]
  def change
    create_table :news_items do |t|
      t.string :source
      t.datetime :published_at
      t.text :body

      t.timestamps
    end
  end
end
