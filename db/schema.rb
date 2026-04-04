# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_05_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "map_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "map_name"
    t.bigint "match_id", null: false
    t.integer "pandascore_id"
    t.string "score"
    t.datetime "updated_at", null: false
    t.bigint "winner_team_id"
    t.index ["match_id"], name: "index_map_results_on_match_id"
    t.index ["pandascore_id"], name: "index_map_results_on_pandascore_id", unique: true
    t.index ["winner_team_id"], name: "index_map_results_on_winner_team_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "begin_at"
    t.datetime "created_at", null: false
    t.datetime "end_at"
    t.integer "hltv_id"
    t.bigint "league_id"
    t.string "league_name"
    t.string "match_type"
    t.integer "pandascore_id"
    t.datetime "played_at"
    t.string "score"
    t.bigint "serie_id"
    t.string "serie_name"
    t.string "status"
    t.bigint "team1_id", null: false
    t.bigint "team2_id", null: false
    t.string "tournament"
    t.bigint "tournament_id"
    t.string "tournament_name"
    t.datetime "updated_at", null: false
    t.bigint "winner_id"
    t.index ["hltv_id"], name: "index_matches_on_hltv_id", unique: true
    t.index ["pandascore_id"], name: "index_matches_on_pandascore_id", unique: true
    t.index ["team1_id"], name: "index_matches_on_team1_id"
    t.index ["team2_id"], name: "index_matches_on_team2_id"
    t.index ["winner_id"], name: "index_matches_on_winner_id"
  end

  create_table "news_items", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.string "source"
    t.datetime "updated_at", null: false
  end

  create_table "player_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "deaths"
    t.integer "kills"
    t.bigint "match_id", null: false
    t.bigint "player_id", null: false
    t.decimal "rating"
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_player_stats_on_match_id"
    t.index ["player_id"], name: "index_player_stats_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "pandascore_id"
    t.string "role"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pandascore_id"], name: "index_players_on_pandascore_id", unique: true
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "acronym"
    t.datetime "created_at", null: false
    t.integer "hltv_id"
    t.integer "hltv_rank"
    t.string "image_url"
    t.string "name"
    t.integer "pandascore_id"
    t.integer "pandascore_rank"
    t.string "region"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["hltv_id"], name: "index_teams_on_hltv_id", unique: true
    t.index ["pandascore_id"], name: "index_teams_on_pandascore_id", unique: true
  end

  add_foreign_key "map_results", "matches"
  add_foreign_key "map_results", "teams", column: "winner_team_id"
  add_foreign_key "matches", "teams", column: "team1_id"
  add_foreign_key "matches", "teams", column: "team2_id"
  add_foreign_key "matches", "teams", column: "winner_id"
  add_foreign_key "player_stats", "matches"
  add_foreign_key "player_stats", "players"
  add_foreign_key "players", "teams"
end
