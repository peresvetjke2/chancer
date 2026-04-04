namespace :pandascore do
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
