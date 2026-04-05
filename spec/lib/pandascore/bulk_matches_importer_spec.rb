require "rails_helper"

RSpec.describe Pandascore::BulkMatchesImporter do
  let(:client)   { instance_double(Pandascore::Client) }
  subject(:importer) { described_class.new(client: client) }

  def call_importer
    importer.call(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 3, 31))
  end

  def build_match(id:, team1_id:, team2_id:, begin_at: "2026-02-01T10:00:00Z",
                  end_at: "2026-02-01T12:00:00Z", games: [])
    {
      "id"         => id,
      "begin_at"   => begin_at,
      "end_at"     => end_at,
      "match_type" => "best_of_3",
      "status"     => "finished",
      "league"     => { "id" => 1, "name" => "L" },
      "serie"      => { "id" => 2, "name" => "S" },
      "tournament" => { "id" => 3, "name" => "T" },
      "games"      => games,
      "opponents"  => [
        { "opponent" => { "id" => team1_id, "name" => "Team A" } },
        { "opponent" => { "id" => team2_id, "name" => "Team B" } }
      ],
      "winner"  => { "id" => team1_id },
      "results" => [
        { "team_id" => team1_id, "score" => 2 },
        { "team_id" => team2_id, "score" => 0 }
      ]
    }
  end

  # AC-1: базовый случай — 2 матча + пустая страница 2
  context "AC-1: однострочный ответ" do
    let(:page1) do
      [
        build_match(id: 1, team1_id: 101, team2_id: 202),
        build_match(id: 2, team1_id: 303, team2_id: 404)
      ]
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return(page1)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "импортирует оба матча" do
      call_importer
      expect(Match.count).to eq(2)
    end

    it "возвращает уникальные team_ids всех участников" do
      result = call_importer
      expect(result).to match_array([101, 202, 303, 404])
    end
  end

  # AC-2: пагинация — 100 + 50 + пустая = 3 вызова, 150 матчей
  context "AC-2: пагинация" do
    let(:page1) do
      (1..100).map { |i| build_match(id: i, team1_id: i * 10, team2_id: i * 10 + 1) }
    end
    let(:page2) do
      (101..150).map { |i| build_match(id: i, team1_id: i * 10, team2_id: i * 10 + 1) }
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return(page1)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return(page2)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 3))
        .and_return([])
    end

    it "выполняет ровно 3 вызова к клиенту" do
      call_importer
      expect(client).to have_received(:get).exactly(3).times
    end

    it "импортирует все 150 матчей" do
      call_importer
      expect(Match.count).to eq(150)
    end
  end

  # AC-3: уникальные pandascore_id — один id встречается в нескольких матчах
  context "AC-3: уникальные team_ids в возвращаемом массиве" do
    let(:page1) do
      [
        build_match(id: 1, team1_id: 101, team2_id: 202),
        build_match(id: 2, team1_id: 101, team2_id: 202)
      ]
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return(page1)
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "возвращает только уникальные id" do
      result = call_importer
      expect(result).to match_array([101, 202])
    end
  end

  # AC-4: opponents < 2 → матч пропускается
  context "AC-4: opponents < 2" do
    let(:bad_match) do
      { "id" => 999, "end_at" => "2026-02-01T12:00:00Z",
        "opponents" => [{ "opponent" => { "id" => 101, "name" => "Team A" } }],
        "winner" => nil, "results" => [], "games" => [],
        "tournament" => nil, "league" => nil, "serie" => nil }
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return([bad_match])
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "пропускает матч без исключения" do
      expect { call_importer }.not_to raise_error
      expect(Match.count).to eq(0)
    end
  end

  # AC-5: end_at: nil → матч пропускается
  context "AC-5: end_at nil" do
    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return([build_match(id: 1, team1_id: 101, team2_id: 202, end_at: nil)])
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "пропускает матч без исключения" do
      expect { call_importer }.not_to raise_error
      expect(Match.count).to eq(0)
    end
  end

  # AC-6: идемпотентность
  context "AC-6: идемпотентность" do
    let(:match_with_game) do
      games = [
        { "id" => 501, "map" => { "name" => "Mirage" },
          "winner" => { "id" => 101 },
          "results" => [{ "team_id" => 101, "score" => 16 },
                        { "team_id" => 202, "score" => 9 }] }
      ]
      build_match(id: 1, team1_id: 101, team2_id: 202, games: games)
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return([match_with_game])
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "повторный прогон не увеличивает Match.count" do
      call_importer
      expect { call_importer }.not_to change(Match, :count)
    end

    it "повторный прогон не увеличивает MapResult.count" do
      call_importer
      expect { call_importer }.not_to change(MapResult, :count)
    end
  end

  # AC-7: карты — 2 сохраняются, 1 с map: nil пропускается
  context "AC-7: сохранение карт" do
    let(:games) do
      [
        { "id" => 601, "map" => { "name" => "Mirage" },
          "winner" => { "id" => 101 },
          "results" => [{ "team_id" => 101, "score" => 16 },
                        { "team_id" => 202, "score" => 9 }] },
        { "id" => 602, "map" => { "name" => "Inferno" },
          "winner" => { "id" => 202 },
          "results" => [{ "team_id" => 101, "score" => 10 },
                        { "team_id" => 202, "score" => 16 }] },
        { "id" => 603, "map" => nil, "winner" => nil, "results" => [] }
      ]
    end

    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return([build_match(id: 1, team1_id: 101, team2_id: 202, games: games)])
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 2))
        .and_return([])
    end

    it "создаёт ровно 2 MapResult (map: nil пропускается)" do
      expect { call_importer }.to change(MapResult, :count).by(2)
    end

    it "сохраняет корректные данные первой карты" do
      call_importer
      mr = MapResult.find_by!(pandascore_id: 601)
      expect(mr.map_name).to eq("Mirage")
      expect(mr.score).to eq("16-9")
      expect(mr.winner_team_id).to eq(Team.find_by!(pandascore_id: 101).id)
    end
  end

  # AC-8: пустой первый ответ → 1 вызов клиента, возврат [], 0 матчей
  context "AC-8: пустой первый ответ" do
    before do
      allow(client).to receive(:get)
        .with("/csgo/matches/past", hash_including("page[number]" => 1))
        .and_return([])
    end

    it "делает ровно 1 вызов к клиенту" do
      call_importer
      expect(client).to have_received(:get).once
    end

    it "возвращает пустой массив" do
      expect(call_importer).to eq([])
    end

    it "не создаёт матчей" do
      call_importer
      expect(Match.count).to eq(0)
    end
  end
end
