require "rails_helper"

RSpec.describe Pandascore::TeamsImporter do
  let(:client) { instance_double(Pandascore::Client) }

  let(:api_teams) do
    (1..10).map do |n|
      { "id" => n, "name" => "Team #{n}", "location" => "EU", "ranking" => n + 4,
        "acronym" => "T#{n}", "image_url" => "https://img/#{n}.png", "slug" => "team-#{n}",
        "players" => [] }
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
    expect(team.pandascore_rank).to eq(5)
  end

  it "sets acronym, image_url, slug" do
    importer.call
    team = Team.find_by!(pandascore_id: 1)
    expect(team.acronym).to eq("T1")
    expect(team.image_url).to eq("https://img/1.png")
    expect(team.slug).to eq("team-1")
  end

  it "takes pandascore_rank from t[ranking], not position" do
    importer.call
    # first team in list has ranking: 5, not 1
    team = Team.find_by!(pandascore_id: 1)
    expect(team.pandascore_rank).to eq(5)
  end

  it "is idempotent — repeated runs don't create duplicates" do
    importer.call
    expect { importer.call }.not_to change(Team, :count)
  end

  context "with players in team data" do
    let(:api_teams) do
      [
        { "id" => 1, "name" => "Team 1", "location" => "EU", "ranking" => 1,
          "acronym" => "T1", "image_url" => nil, "slug" => "team-1",
          "players" => [
            { "id" => 11234, "name" => "s1mple", "role" => "rifler" },
            { "id" => 11235, "name" => "NiKo",   "role" => "rifler" }
          ] }
      ]
    end

    it "creates players with pandascore_id, name, role" do
      importer.call
      player = Player.find_by!(pandascore_id: 11234)
      expect(player.name).to eq("s1mple")
      expect(player.role).to eq("rifler")
      expect(player.team).to eq(Team.find_by!(pandascore_id: 1))
    end

    it "does not duplicate players on repeated runs" do
      importer.call
      expect { importer.call }.not_to change(Player, :count)
    end
  end
end
