module Pandascore
  class TeamsImporter
    def initialize(client:)
      @client = client
    end

    def call
      Rails.logger.info "TeamsImporter: start"

      teams = @client.get("/csgo/teams", sort: "ranking", "page[size]": 10)

      rows = teams.map do |t|
        { pandascore_id: t["id"], name: t["name"],
          region: t["location"], pandascore_rank: t["ranking"],
          acronym: t["acronym"], image_url: t["image_url"], slug: t["slug"] }
      end

      Team.upsert_all(rows, unique_by: :pandascore_id,
        update_only: %i[name region pandascore_rank acronym image_url slug])

      teams.each do |t|
        next if t["players"].blank?
        team = Team.find_by!(pandascore_id: t["id"])
        Array(t["players"]).each do |p|
          Player.find_or_create_by(pandascore_id: p["id"]) do |player|
            player.name    = p["name"]
            player.role    = p["role"]
            player.team_id = team.id
          end
        end
      end

      Rails.logger.info "TeamsImporter: done, upserted #{rows.size}"
      rows.size
    end
  end
end
