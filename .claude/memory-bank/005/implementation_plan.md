# Implementation Plan: задача 005 — Расширение данных PandaScore

Related spec: [spec.md](spec.md)

## Статус: не начато

---

## Шаг 1 — Миграция (одна миграция, все 4 таблицы)

Создать `db/migrate/<timestamp>_expand_pandascore_data.rb`.

### `teams`
```ruby
add_column :teams, :acronym,   :string
add_column :teams, :image_url, :string
add_column :teams, :slug,      :string
```

### `matches`
```ruby
add_column :matches, :begin_at,        :datetime
add_column :matches, :end_at,          :datetime
add_column :matches, :match_type,      :string
add_column :matches, :status,          :string
add_column :matches, :league_id,       :bigint
add_column :matches, :league_name,     :string
add_column :matches, :serie_id,        :bigint
add_column :matches, :serie_name,      :string
add_column :matches, :tournament_id,   :bigint
add_column :matches, :tournament_name, :string
```

> Колонка `tournament` (string, уже существует) **не трогается**. Добавляется `tournament_name` как новая колонка — временное дублирование данных намеренно. Колонка `tournament` удаляется отдельной задачей после завершения 007–009.

### `map_results`
```ruby
add_column :map_results, :pandascore_id,  :integer
add_column :map_results, :winner_team_id, :bigint
add_foreign_key :map_results, :teams, column: :winner_team_id
add_index :map_results, :pandascore_id, unique: true
add_index :map_results, :winner_team_id
```

### `players`
```ruby
add_column :players, :pandascore_id, :integer
add_index :players, :pandascore_id, unique: true
```

Запустить: `bin/rails db:migrate`

---

## Шаг 2 — Модели

### `app/models/map_result.rb`
- Добавить `belongs_to :winner_team, class_name: "Team", optional: true`
- Убрать/не трогать `validates :map_name, presence: true` (остаётся)

### `app/models/player.rb`
- Добавить `validates :pandascore_id, uniqueness: true, allow_nil: true`
- `belongs_to :team` **не трогать** — `team_id` проставляется в блоке `find_or_create_by` до валидации, `optional: true` не нужен и создаёт ложную безопасность (БД имеет `null: false`)

---

## Шаг 3 — `TeamsImporter`

Файл: `lib/pandascore/teams_importer.rb`

**Изменения:**

1. Изменить параметры запроса: добавить `sort: "ranking"` (уже есть в тесте, но не в коде — проверить).
2. В `rows.map`: заменить `pandascore_rank: i + 1` на `pandascore_rank: t["ranking"]`.
3. Добавить в `rows`: `acronym: t["acronym"]`, `image_url: t["image_url"]`, `slug: t["slug"]`.
4. Обновить `update_only` в `upsert_all`: добавить `acronym`, `image_url`, `slug`, `pandascore_rank`.
5. После `upsert_all` — цикл по командам для upsert игроков:

```ruby
teams.each do |t|
  next if t["players"].blank?
  team = Team.find_by!(pandascore_id: t["id"])
  Array(t["players"]).each do |p|
    Player.find_or_create_by(pandascore_id: p["id"]) do |player|
      player.name    = p["name"]
      player.role    = p["role"]
      player.team_id = team.id
    end
  end
end
```

---

## Шаг 4 — `MatchesImporter`

Файл: `lib/pandascore/matches_importer.rb`

**Изменения:**

1. В `Match.upsert` добавить новые поля:
   ```ruby
   begin_at:        match["begin_at"],
   end_at:          match["end_at"],
   match_type:      match["match_type"],
   status:          match["status"],
   league_id:       match.dig("league", "id"),
   league_name:     match.dig("league", "name"),
   serie_id:        match.dig("serie", "id"),
   serie_name:      match.dig("serie", "name"),
   tournament_id:   match.dig("tournament", "id"),
   tournament_name: match.dig("tournament", "name"),
   ```
2. Добавить все новые поля в `update_only`.
3. После `Match.upsert` — upsert карт из `match["games"]`:

```ruby
saved_match = Match.find_by!(pandascore_id: match["id"])

Array(match["games"]).each do |game|
  next if game["map"].nil?
  next if game["id"].nil?

  winner_ps_id = game.dig("winner", "id")
  winner_team  = winner_ps_id ? Team.find_by(pandascore_id: winner_ps_id) : nil

  results = game["results"] || []
  r1    = results.find { |r| r["team_id"] == match.dig("opponents", 0, "opponent", "id") }
  r2    = results.find { |r| r["team_id"] == match.dig("opponents", 1, "opponent", "id") }
  score = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil

  MapResult.find_or_create_by(pandascore_id: game["id"]) do |mr|
    mr.match_id       = saved_match.id
    mr.map_name       = game.dig("map", "name")
    mr.score          = score
    mr.winner_team_id = winner_team&.id
  end
end
```

---

## Шаг 5 — Тесты `teams_importer_spec.rb`

**Обновить fixture `api_teams`:**
- Добавить `"acronym"`, `"image_url"`, `"slug"`, `"players"` (массив с `id`, `name`, `role`)
- Пример игрока: `{ "id" => 11234, "name" => "s1mple", "role" => "rifler" }`

**Добавить/обновить тесты:**
- `pandascore_rank` берётся из `t["ranking"]`, не из позиции (тест: команда с `ranking: 5` должна иметь `pandascore_rank: 5`, а не `1`)
- `acronym`, `image_url`, `slug` сохраняются корректно
- Игрок создан: `pandascore_id: 11234`, `name: "s1mple"`, `role: "rifler"`
- Повторный импорт не дублирует игроков (`Player.count` не меняется)

**Обновить `before` блок:** изменить параметр запроса на `sort: "ranking"` если не совпадает с текущим кодом.

---

## Шаг 6 — Тесты `matches_importer_spec.rb`

**Обновить `build_match`:** добавить в fixture новые поля, **но `"games"` по умолчанию `[]`** — чтобы не сломать существующие контексты (AC-7, AC-8, idempotency и др.), которые не ожидают создания `MapResult`:
```ruby
"begin_at"   => "2026-03-29T10:00:00Z",
"match_type" => "best_of_3",
"status"     => "finished",
"league"     => { "id" => 101, "name" => "ESL Pro League" },
"serie"      => { "id" => 201, "name" => "Season 20" },
"tournament" => { "id" => 301, "name" => "ESL Pro League S20" },
"games"      => [],   # дефолт — пустой массив
```

Конкретные `games` передаются только в новом контексте AC-005 через параметр `build_match(..., games: [...])` или через `let` с merge:
```ruby
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
```

**Добавить тесты (новый context "AC-005: новые поля матча и карты"):**
- Матч сохраняет `begin_at`, `end_at`, `match_type`, `status`, `league_id`, `league_name`, `serie_id`, `serie_name`, `tournament_id`, `tournament_name`
- Создаётся ровно 2 `MapResult` (третий `map: nil` пропускается)
- Первый `MapResult`: `pandascore_id: 301`, `score: "16-9"`, `winner_team_id: t1.id`, `map_name: "Mirage"`
- Повторный импорт не дублирует карты (`MapResult.count` не меняется)

---

## Порядок выполнения

1. [ ] Шаг 1: миграция + `bin/rails db:migrate`
2. [ ] Шаг 2: модели
3. [ ] Шаг 3: `TeamsImporter`
4. [ ] Шаг 4: `MatchesImporter`
5. [ ] Шаг 5: тесты `TeamsImporter`
6. [ ] Шаг 6: тесты `MatchesImporter`
7. [ ] Прогнать `bundle exec rspec` — все зелёные

---

## Риски / замечания

- `Player.find_or_create_by(pandascore_id:) { |p| p.team_id = ... }` — блок выполняется до валидации, поэтому `belongs_to :team` (без `optional: true`) работает корректно. `optional: true` добавлять не нужно.
- Текущий тест `TeamsImporter` ожидает параметр `sort: "ranking"` в запросе, но текущий код его не передаёт — нужно добавить в `client.get`.
- `MapResult` валидирует `map_name: presence: true` — при создании через `find_or_create_by` `map_name` проставляется в блоке, проблем нет. Но если `game.dig("map", "name")` вернёт nil (при `"map" => { "name" => nil }`), валидация упадёт. По спеке пропускаем только `game["map"].nil?` — такой кейс в граничных случаях не упоминается; оставляем как есть.
