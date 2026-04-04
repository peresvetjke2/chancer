require "rails_helper"

RSpec.describe Pandascore::MatchesImporter do
  let(:client) { instance_double(Pandascore::Client) }
  subject(:importer) { described_class.new(client: client) }

  let(:teams) { create_list(:pandascore_team, 10) }

  def build_match(id:, team1:, team2:, winner: team1, end_at: "2026-04-01T12:00:00Z")
    {
      "id" => id,
      "end_at" => end_at,
      "opponents" => [
        { "opponent" => { "id" => team1.pandascore_id, "name" => team1.name } },
        { "opponent" => { "id" => team2.pandascore_id, "name" => team2.name } }
      ],
      "winner" => winner ? { "id" => winner.pandascore_id } : nil,
      "results" => [
        { "team_id" => team1.pandascore_id, "score" => 2 },
        { "team_id" => team2.pandascore_id, "score" => 0 }
      ],
      "tournament" => { "name" => "ESL Pro League" }
    }
  end

  before do
    teams # ensure teams are created
    allow(client).to receive(:get).and_return([])
  end

  context "AC-7: match with opponents < 2" do
    let(:team) { teams.first }
    let(:bad_match) do
      { "id" => 999, "end_at" => "2026-04-01T12:00:00Z",
        "opponents" => [{ "opponent" => { "id" => team.pandascore_id, "name" => team.name } }],
        "winner" => nil, "results" => [], "tournament" => nil }
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": team.pandascore_id))
        .and_return([bad_match])
    end

    it "skips the match without raising" do
      expect { importer.call }.not_to raise_error
      expect(Match.count).to eq(0)
    end
  end

  context "AC-8: match with winner null" do
    let(:t1) { teams[0] }
    let(:t2) { teams[1] }

    before do
      match = build_match(id: 1, team1: t1, team2: t2, winner: nil)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": t1.pandascore_id))
        .and_return([match])
    end

    it "saves the match with winner_id nil" do
      importer.call
      m = Match.find_by!(pandascore_id: 1)
      expect(m.winner_id).to be_nil
    end
  end

  context "AC-9: match with end_at null" do
    let(:team) { teams.first }

    before do
      match = build_match(id: 2, team1: team, team2: teams[1], end_at: nil)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": team.pandascore_id))
        .and_return([match])
    end

    it "skips the match without raising" do
      expect { importer.call }.not_to raise_error
      expect(Match.count).to eq(0)
    end
  end

  context "idempotency" do
    let(:t1) { teams[0] }
    let(:t2) { teams[1] }

    before do
      match = build_match(id: 10, team1: t1, team2: t2)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": t1.pandascore_id))
        .and_return([match])
    end

    it "does not create duplicate matches on repeated runs" do
      importer.call
      expect { importer.call }.not_to change(Match, :count)
    end
  end

  context "minimal team creation for non-top-10 opponent" do
    let(:top_team) { teams.first }
    let(:unknown_pandascore_id) { 9999 }

    before do
      match = build_match(id: 20, team1: top_team, team2: top_team).merge(
        "opponents" => [
          { "opponent" => { "id" => top_team.pandascore_id, "name" => top_team.name } },
          { "opponent" => { "id" => unknown_pandascore_id, "name" => "Unknown Team" } }
        ],
        "results" => [
          { "team_id" => top_team.pandascore_id, "score" => 2 },
          { "team_id" => unknown_pandascore_id, "score" => 1 }
        ]
      )
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": top_team.pandascore_id))
        .and_return([match])
    end

    it "creates a minimal team record for the unknown opponent" do
      expect { importer.call }.to change(Team, :count).by(1)
      new_team = Team.find_by!(pandascore_id: unknown_pandascore_id)
      expect(new_team.name).to eq("Unknown Team")
    end
  end
end
