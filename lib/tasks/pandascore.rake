namespace :pandascore do
  desc "Bulk-import CS2 match history for the last N months (default: 3)"
  task :import_history, [:months] => :environment do |_, args|
    months = (args[:months] || 3).to_i
    token  = ENV["PANDASCORE_API_TOKEN"]
    abort "PANDASCORE_API_TOKEN is not set" if token.blank?

    client     = Pandascore::Client.new(token: token)
    start_date = months.months.ago.to_date
    end_date   = Date.today

    team_ids = Pandascore::BulkMatchesImporter.new(client: client)
                 .call(start_date: start_date, end_date: end_date)

    puts "Matches upserted: #{Match.count}"
    puts "Participating team pandascore_ids (#{team_ids.size}):"
    puts team_ids.sort.join(", ")
  end

  desc "Import top-10 CS2 teams and their recent matches from PandaScore"
  task import: :environment do
    token = ENV["PANDASCORE_API_TOKEN"]
    abort "PANDASCORE_API_TOKEN is not set" if token.blank?

    client = Pandascore::Client.new(token: token)

    teams_count = Pandascore::TeamsImporter.new(client: client).call
    matches_count = Pandascore::MatchesImporter.new(client: client).call

    puts "Teams upserted: #{teams_count}"
    puts "Matches upserted: #{matches_count}"
  end
end
