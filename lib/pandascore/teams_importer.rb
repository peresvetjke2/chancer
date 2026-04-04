module Pandascore
  class TeamsImporter
    def initialize(client:)
      @client = client
    end

    def call
      Rails.logger.info "TeamsImporter: start"

      teams = @client.get("/csgo/teams", "page[size]": 10)

      rows = teams.each_with_index.map do |t, i|
        { pandascore_id: t["id"], name: t["name"],
          region: t["location"], pandascore_rank: i + 1 }
      end

      Team.upsert_all(rows, unique_by: :pandascore_id, update_only: %i[name region pandascore_rank])

      Rails.logger.info "TeamsImporter: done, upserted #{rows.size}"
      rows.size
    end
  end
end
