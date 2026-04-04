require "rails_helper"

RSpec.describe Pandascore::TeamsImporter do
  let(:client) { instance_double(Pandascore::Client) }

  let(:api_teams) do
    (1..10).map do |n|
      { "id" => n, "name" => "Team #{n}", "location" => "EU", "ranking" => n }
    end
  end

  before do
    allow(client).to receive(:get)
      .with("/csgo/teams", sort: "ranking", "page[size]": 10)
      .and_return(api_teams)
  end

  subject(:importer) { described_class.new(client: client) }

  it "upserts 10 teams and returns 10" do
    expect { importer.call }.to change(Team, :count).by(10)
    expect(importer.call).to eq(10)
  end

  it "sets pandascore_id, name, region, pandascore_rank" do
    importer.call
    team = Team.find_by!(pandascore_id: 1)
    expect(team.name).to eq("Team 1")
    expect(team.region).to eq("EU")
    expect(team.pandascore_rank).to eq(1)
  end

  it "is idempotent — repeated runs don't create duplicates" do
    importer.call
    expect { importer.call }.not_to change(Team, :count)
  end
end
