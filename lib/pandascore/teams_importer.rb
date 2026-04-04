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
          region: t["location"], pandascore_rank: t["ranking"] }
      end

      Team.upsert_all(rows, unique_by: :pandascore_id, update_only: %i[name region pandascore_rank])

      Rails.logger.info "TeamsImporter: done, upserted #{rows.size}"
      rows.size
    end
  end
end
