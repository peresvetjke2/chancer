module Pandascore
  class MatchesImporter
    def initialize(client:)
      @client = client
    end

    def call
      Rails.logger.info "MatchesImporter: start"

      teams = Team.where.not(pandascore_id: nil).order(:pandascore_rank).limit(10)
      count = 0

      teams.each do |team|
        now = Time.current.iso8601
        seven_days_ago = 7.days.ago.iso8601

        matches = @client.get(
          "/csgo/matches/past",
          "filter[opponent_id]": team.pandascore_id,
          "range[end_at]": "#{seven_days_ago},#{now}"
        )

        matches.each do |match|
          if match["opponents"].length < 2
            Rails.logger.warn "MatchesImporter: skip match #{match["id"]}, opponents < 2"
            next
          end

          if match["end_at"].nil?
            Rails.logger.warn "MatchesImporter: skip match #{match["id"]}, end_at is null"
            next
          end

          team1 = find_or_create_minimal_team(match["opponents"][0]["opponent"])
          team2 = find_or_create_minimal_team(match["opponents"][1]["opponent"])

          winner_data = match["winner"]
          winner = winner_data ? Team.find_by(pandascore_id: winner_data["id"]) : nil

          results = match["results"] || []
          r1 = results.find { |r| r["team_id"] == team1.pandascore_id }
          r2 = results.find { |r| r["team_id"] == team2.pandascore_id }
          score = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil

          Match.upsert(
            { pandascore_id: match["id"], team1_id: team1.id, team2_id: team2.id,
              winner_id: winner&.id, score: score,
              tournament: match.dig("tournament", "name"),
              played_at: match["end_at"] },
            unique_by: :pandascore_id,
            update_only: %i[team1_id team2_id winner_id score tournament played_at]
          )
          count += 1
        end
      end

      Rails.logger.info "MatchesImporter: done, upserted #{count}"
      count
    end

    private

    def find_or_create_minimal_team(opponent_data)
      Team.find_or_create_by(pandascore_id: opponent_data["id"]) do |t|
        t.name = opponent_data["name"]
      end
    end
  end
end
