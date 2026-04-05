require "set"

module Pandascore
  class BulkMatchesImporter
    def initialize(client:)
      @client = client
    end

    def call(start_date:, end_date:)
      page     = 1
      team_ids = Set.new

      loop do
        matches = @client.get(
          "/csgo/matches/past",
          "range[begin_at]" => "#{start_date},#{end_date}",
          "page[size]"      => 100,
          "page[number]"    => page
        )

        break if matches.empty?

        matches.each do |match|
          next if match["opponents"].length < 2
          next if match["end_at"].nil?

          import_match(match)

          match["opponents"].each do |opp|
            id = opp.dig("opponent", "id")
            team_ids << id if id
          end
        end

        page += 1
      end

      team_ids.to_a
    end

    private

    def import_match(match)
      team1 = find_or_create_minimal_team(match["opponents"][0]["opponent"])
      team2 = find_or_create_minimal_team(match["opponents"][1]["opponent"])

      winner_data = match["winner"]
      winner      = winner_data ? Team.find_by(pandascore_id: winner_data["id"]) : nil

      results = match["results"] || []
      r1      = results.find { |r| r["team_id"] == team1.pandascore_id }
      r2      = results.find { |r| r["team_id"] == team2.pandascore_id }
      score   = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil

      Match.upsert(
        { pandascore_id: match["id"], team1_id: team1.id, team2_id: team2.id,
          winner_id: winner&.id, score: score,
          tournament:      match.dig("tournament", "name"),
          played_at:       match["end_at"],
          begin_at:        match["begin_at"],
          end_at:          match["end_at"],
          match_type:      match["match_type"],
          status:          match["status"],
          league_id:       match.dig("league", "id"),
          league_name:     match.dig("league", "name"),
          serie_id:        match.dig("serie", "id"),
          serie_name:      match.dig("serie", "name"),
          tournament_id:   match.dig("tournament", "id"),
          tournament_name: match.dig("tournament", "name") },
        unique_by: :pandascore_id,
        update_only: %i[team1_id team2_id winner_id score tournament played_at
                        begin_at end_at match_type status
                        league_id league_name serie_id serie_name
                        tournament_id tournament_name]
      )

      saved_match = Match.find_by!(pandascore_id: match["id"])

      Array(match["games"]).each do |game|
        next if game["map"].nil?
        next if game["id"].nil?

        winner_ps_id = game.dig("winner", "id")
        winner_team  = winner_ps_id ? Team.find_by(pandascore_id: winner_ps_id) : nil

        game_results = game["results"] || []
        gr1      = game_results.find { |r| r["team_id"] == match.dig("opponents", 0, "opponent", "id") }
        gr2      = game_results.find { |r| r["team_id"] == match.dig("opponents", 1, "opponent", "id") }
        map_score = (gr1 && gr2) ? "#{gr1["score"]}-#{gr2["score"]}" : nil

        MapResult.find_or_create_by(pandascore_id: game["id"]) do |mr|
          mr.match_id       = saved_match.id
          mr.map_name       = game.dig("map", "name")
          mr.score          = map_score
          mr.winner_team_id = winner_team&.id
        end
      end
    end

    def find_or_create_minimal_team(opponent_data)
      Team.find_or_create_by(pandascore_id: opponent_data["id"]) do |t|
        t.name = opponent_data["name"]
      end
    end
  end
end
