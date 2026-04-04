require "rails_helper"

RSpec.describe Pandascore::MatchesImporter do
  let(:client) { instance_double(Pandascore::Client) }
  subject(:importer) { described_class.new(client: client) }

  let(:teams) { create_list(:pandascore_team, 10) }

  def build_match(id:, team1:, team2:, winner: team1, end_at: "2026-04-01T12:00:00Z", games: [])
    {
      "id" => id,
      "end_at" => end_at,
      "begin_at"   => "2026-03-29T10:00:00Z",
      "match_type" => "best_of_3",
      "status"     => "finished",
      "league"     => { "id" => 101, "name" => "ESL Pro League" },
      "serie"      => { "id" => 201, "name" => "Season 20" },
      "tournament" => { "id" => 301, "name" => "ESL Pro League S20" },
      "games"      => games,
      "opponents" => [
        { "opponent" => { "id" => team1.pandascore_id, "name" => team1.name } },
        { "opponent" => { "id" => team2.pandascore_id, "name" => team2.name } }
      ],
      "winner" => winner ? { "id" => winner.pandascore_id } : nil,
      "results" => [
        { "team_id" => team1.pandascore_id, "score" => 2 },
        { "team_id" => team2.pandascore_id, "score" => 0 }
      ]
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

  context "AC-005: новые поля матча и карты" do
    let(:t1) { teams[0] }
    let(:t2) { teams[1] }

    let(:games) do
      [
        { "id" => 301, "map" => { "name" => "Mirage" },
          "winner" => { "id" => t1.pandascore_id },
          "results" => [{ "team_id" => t1.pandascore_id, "score" => 16 },
                        { "team_id" => t2.pandascore_id, "score" => 9 }] },
        { "id" => 302, "map" => { "name" => "Inferno" },
          "winner" => { "id" => t1.pandascore_id },
          "results" => [{ "team_id" => t1.pandascore_id, "score" => 16 },
                        { "team_id" => t2.pandascore_id, "score" => 14 }] },
        { "id" => nil, "map" => nil, "winner" => nil, "results" => [] }
      ]
    end

    before do
      match = build_match(id: 50, team1: t1, team2: t2, games: games)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("filter[opponent_id]": t1.pandascore_id))
        .and_return([match])
    end

    it "saves новые поля матча" do
      importer.call
      m = Match.find_by!(pandascore_id: 50)
      expect(m.begin_at).to eq(Time.parse("2026-03-29T10:00:00Z"))
      expect(m.match_type).to eq("best_of_3")
      expect(m.status).to eq("finished")
      expect(m.league_id).to eq(101)
      expect(m.league_name).to eq("ESL Pro League")
      expect(m.serie_id).to eq(201)
      expect(m.serie_name).to eq("Season 20")
      expect(m.tournament_id).to eq(301)
      expect(m.tournament_name).to eq("ESL Pro League S20")
    end

    it "создаёт ровно 2 MapResult (map: nil пропускается)" do
      expect { importer.call }.to change(MapResult, :count).by(2)
    end

    it "сохраняет поля первой карты корректно" do
      importer.call
      mr = MapResult.find_by!(pandascore_id: 301)
      expect(mr.map_name).to eq("Mirage")
      expect(mr.score).to eq("16-9")
      expect(mr.winner_team_id).to eq(t1.id)
    end

    it "повторный импорт не дублирует карты" do
      importer.call
      expect { importer.call }.not_to change(MapResult, :count)
    end
  end
end
