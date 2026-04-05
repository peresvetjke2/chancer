# Implementation Plan: задача 006 — BulkMatchesImporter

## Решение по архитектуре

Код `import_match` и `find_or_create_minimal_team` **дублируется** из `MatchesImporter` —
спека явно допускает это; рефакторинг — отдельная задача.
`MapResult` сохраняется через `find_or_create_by` (как в оригинале) — из соображений
единообразия с `MatchesImporter`. У `MapResult` уникальный индекс по `pandascore_id` есть
(`db/schema.rb:26-27`), но переходить на `upsert` — отдельная задача.

---

## Шаги

### 1. Создать `lib/pandascore/bulk_matches_importer.rb`

```ruby
require "set"

module Pandascore
  class BulkMatchesImporter
    def initialize(client:)
      @client = client
    end

    def call(start_date:, end_date:)
      page     = 1
      team_ids = Set.new

      loop do
        matches = @client.get(
          "/csgo/matches/past",
          "range[begin_at]" => "#{start_date},#{end_date}",
          "page[size]"      => 100,
          "page[number]"    => page
        )

        break if matches.empty?

        matches.each do |match|
          next if match["opponents"].length < 2
          next if match["end_at"].nil?

          import_match(match)

          match["opponents"].each do |opp|
            id = opp.dig("opponent", "id")
            team_ids << id if id
          end
        end

        page += 1
      end

      team_ids.to_a
    end

    private

    def import_match(match)
      team1 = find_or_create_minimal_team(match["opponents"][0]["opponent"])
      team2 = find_or_create_minimal_team(match["opponents"][1]["opponent"])

      winner_data = match["winner"]
      winner      = winner_data ? Team.find_by(pandascore_id: winner_data["id"]) : nil

      results = match["results"] || []
      r1      = results.find { |r| r["team_id"] == team1.pandascore_id }
      r2      = results.find { |r| r["team_id"] == team2.pandascore_id }
      score   = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil

      Match.upsert(
        { pandascore_id: match["id"], team1_id: team1.id, team2_id: team2.id,
          winner_id: winner&.id, score: score,
          tournament:      match.dig("tournament", "name"),
          played_at:       match["end_at"],
          begin_at:        match["begin_at"],
          end_at:          match["end_at"],
          match_type:      match["match_type"],
          status:          match["status"],
          league_id:       match.dig("league", "id"),
          league_name:     match.dig("league", "name"),
          serie_id:        match.dig("serie", "id"),
          serie_name:      match.dig("serie", "name"),
          tournament_id:   match.dig("tournament", "id"),
          tournament_name: match.dig("tournament", "name") },
        unique_by: :pandascore_id,
        update_only: %i[team1_id team2_id winner_id score tournament played_at
                        begin_at end_at match_type status
                        league_id league_name serie_id serie_name
                        tournament_id tournament_name]
      )

      saved_match = Match.find_by!(pandascore_id: match["id"])

      Array(match["games"]).each do |game|
        next if game["map"].nil?
        next if game["id"].nil?

        winner_ps_id = game.dig("winner", "id")
        winner_team  = winner_ps_id ? Team.find_by(pandascore_id: winner_ps_id) : nil

        game_results = game["results"] || []
        gr1   = game_results.find { |r| r["team_id"] == match.dig("opponents", 0, "opponent", "id") }
        gr2   = game_results.find { |r| r["team_id"] == match.dig("opponents", 1, "opponent", "id") }
        map_score = (gr1 && gr2) ? "#{gr1["score"]}-#{gr2["score"]}" : nil

        MapResult.find_or_create_by(pandascore_id: game["id"]) do |mr|
          mr.match_id       = saved_match.id
          mr.map_name       = game.dig("map", "name")
          mr.score          = map_score
          mr.winner_team_id = winner_team&.id
        end
      end
    end

    def find_or_create_minimal_team(opponent_data)
      Team.find_or_create_by(pandascore_id: opponent_data["id"]) do |t|
        t.name = opponent_data["name"]
      end
    end
  end
end
```

---

### 2. Добавить задачу в `lib/tasks/pandascore.rake`

Дописать в конец существующего namespace (или добавить второй `namespace :pandascore` блок):

```ruby
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
```

---

### 3. Написать `spec/lib/pandascore/bulk_matches_importer_spec.rb`

Структура файла (8 контекстов по спеке):

```
RSpec.describe Pandascore::BulkMatchesImporter do
  let(:client)   { instance_double(Pandascore::Client) }
  subject(:importer) { described_class.new(client: client) }

  # Хелпер: собирает вложенную структуру, которую ожидает importer
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

  # AC-1: однострочный ответ (2 матча + пустая страница 2)
  # AC-2: пагинация (100 + 50 + пустая = 3 вызова, 150 матчей)
  # AC-3: уникальные pandascore_id (два матча с одной парой → [101, 202])
  # AC-4: opponents < 2 → Match.count == 0, нет исключения
  # AC-5: end_at: nil → Match.count == 0
  # AC-6: идемпотентность (два прогона → Match.count и MapResult.count не растут)
  # AC-7: карты (2 сохраняются, 1 с map: nil пропускается)
  # AC-8: пустой первый ответ → 1 вызов клиента, возврат [], 0 матчей
end
```

Ключевые моменты в тестах:
- Для AC-2 генерировать 100 уникальных матчей (`build_match` с разными `id` и `team1_id/team2_id`).
  Команды при этом должны иметь уникальные `pandascore_id`; можно создавать минимальные хэши,
  т.к. `find_or_create_minimal_team` создаёт Team по `pandascore_id` из ответа — БД-записей
  заранее создавать не нужно.
- Мокировать `client.get` с матчером по `"page[number]"`:
  ```ruby
  allow(client).to receive(:get)
    .with("/csgo/matches/past", hash_including("page[number]" => 1))
    .and_return(page1_matches)
  ```

---

## Чеклист

- [ ] Создать `lib/pandascore/bulk_matches_importer.rb`
- [ ] Добавить задачу `:import_history` в `lib/tasks/pandascore.rake`
- [ ] Написать `spec/lib/pandascore/bulk_matches_importer_spec.rb` (AC-1..AC-8)
- [ ] Прогнать `bundle exec rspec spec/lib/pandascore/bulk_matches_importer_spec.rb`
- [ ] Убедиться, что существующий `matches_importer_spec.rb` не сломался
