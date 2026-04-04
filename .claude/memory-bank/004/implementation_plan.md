# Implementation Plan: PandaScore API Integration (CS2)

Spec: `.claude/memory-bank/004/spec.md`

---

## Важные замечания по текущей схеме

- `Team` модель: `validates :hltv_id, presence: true, uniqueness: true` — нужно ослабить, т.к. минимальные записи команд (FR-2) не будут иметь `hltv_id`. Изменить на `validates :hltv_id, uniqueness: true, allow_nil: true`.
- `matches.team1_id` / `matches.team2_id` — `null: false` на уровне БД — OK, мы всегда резолвим обоих участников перед сохранением.
- `Match` модель: `validates :played_at, presence: true` — OK, матчи с `end_at: null` пропускаются.
- `webmock` нет в Gemfile. Не добавляем новые гемы — HTTP-клиент делаем с инъекцией зависимости, в тестах передаём stub-объект.

---

## Шаги

### Шаг 1. Миграции

Создать две миграции (существующие не трогать):

**`db/migrate/<ts>_add_pandascore_fields_to_teams.rb`**
```ruby
add_column :teams, :pandascore_id, :integer
add_column :teams, :pandascore_rank, :integer
add_index :teams, :pandascore_id, unique: true
```

**`db/migrate/<ts>_add_pandascore_id_to_matches.rb`**
```ruby
add_column :matches, :pandascore_id, :integer
add_index :matches, :pandascore_id, unique: true
```

Запустить: `bin/rails db:migrate`

---

### Шаг 2. Обновить модель Team

В `app/models/team.rb` изменить валидацию:
```ruby
# было:
validates :hltv_id, presence: true, uniqueness: true
# стало:
validates :hltv_id, uniqueness: true, allow_nil: true
```

---

### Шаг 3. HTTP-клиент: `lib/pandascore/client.rb`

Использует `Net::HTTP` (stdlib). Принимает `token` и опциональный `http` (для тестов).

Публичный интерфейс:
```ruby
client = Pandascore::Client.new(token: ENV["PANDASCORE_API_TOKEN"])
client.get("/csgo/teams", sort: "ranking", "page[size]": 10)   # => Array (parsed JSON)
client.get("/csgo/matches/past", "filter[opponent_id]": id, ...)
```

Поведение:
- Заголовок `Authorization: Bearer <token>`
- После каждого запроса `sleep 1` (NFR-2)
- Non-2xx или timeout → `Rails.logger.error` с кодом и URL → `raise Pandascore::Error`
- Base URL: `https://api.pandascore.co`

Инъекция для тестов: конструктор принимает `http:` keyword argument (объект с методом `get`).

---

### Шаг 4. Teams Importer: `lib/pandascore/teams_importer.rb`

```ruby
class Pandascore::TeamsImporter
  def initialize(client:)
  def call  # => Integer (количество upsert-записей)
end
```

Логика:
1. `Rails.logger.info "TeamsImporter: start"`
2. `GET /csgo/teams?sort=ranking&page[size]=10`
3. Собрать `rows` — массив хэшей для всех 10 команд:
   ```ruby
   rows = teams.map do |t|
     { pandascore_id: t["id"], name: t["name"],
       region: t["location"], pandascore_rank: t["ranking"] }
   end
   Team.upsert_all(rows, unique_by: :pandascore_id, update_only: %i[name region pandascore_rank])
   ```
4. `Rails.logger.info "TeamsImporter: done, upserted #{rows.size}"`
5. Возвращает `rows.size`

---

### Шаг 5. Matches Importer: `lib/pandascore/matches_importer.rb`

```ruby
class Pandascore::MatchesImporter
  def initialize(client:)
  def call  # => Integer (количество upsert-записей)
end
```

Логика:
1. `Rails.logger.info "MatchesImporter: start"`
2. Загрузить топ-10 команд из БД: `Team.where.not(pandascore_id: nil).order(:pandascore_rank).limit(10)`
3. Для каждой команды:
   - `GET /csgo/matches/past?filter[opponent_id]=<pandascore_id>&range[end_at]=<7_days_ago>,<now>`
   - Для каждого матча в ответе:
     - Если `match["opponents"].length < 2` → `Rails.logger.warn "MatchesImporter: skip match #{match["id"]}, opponents < 2"` → next
     - Если `match["end_at"].nil?` → `Rails.logger.warn "MatchesImporter: skip match #{match["id"]}, end_at is null"` → next
     - Резолвить team1, team2 из `match["opponents"][0]["opponent"]` и `[1]["opponent"]` — через `find_or_create_minimal_team`
     - Резолвить winner: `match["winner"]` → find by pandascore_id, или nil
     - Составить score из `match["results"]`
     - Upsert матча по `pandascore_id`
4. `Rails.logger.info "MatchesImporter: done, upserted #{count}"`
5. Возвращает количество upserted

Вспомогательный метод `find_or_create_minimal_team(opponent_data)`:
```ruby
Team.find_or_create_by(pandascore_id: opponent_data["id"]) do |t|
  t.name = opponent_data["name"]
end
```
Это создаёт минимальную запись (только `pandascore_id` + `name`), если команда не существует.

Score маппинг:
```ruby
results = match["results"] || []
r1 = results.find { |r| r["team_id"] == team1.pandascore_id }
r2 = results.find { |r| r["team_id"] == team2.pandascore_id }
score = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil
```

Upsert матча:
```ruby
Match.upsert(
  { pandascore_id: match["id"], team1_id: team1.id, team2_id: team2.id,
    winner_id: winner&.id, score: score,
    tournament: match.dig("tournament", "name"),
    played_at: match["end_at"] },
  unique_by: :pandascore_id,
  update_only: %i[team1_id team2_id winner_id score tournament played_at]
)
```

---

### Шаг 6. Rake-задача: `lib/tasks/pandascore.rake`

```ruby
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
```

---

### Шаг 7. Обновить фабрику команд

В `spec/factories/teams.rb` добавить фабрику для команд без `hltv_id`:
```ruby
factory :team do
  sequence(:hltv_id) { |n| n }  # оставить как есть
  name { "Natus Vincere" }
  region { "CIS" }
  hltv_rank { 1 }
end

factory :pandascore_team, class: "Team" do
  sequence(:pandascore_id) { |n| n }
  sequence(:pandascore_rank) { |n| n }
  name { "Team Liquid" }
end
```

`pandascore_rank` обязателен — `matches_importer_spec` готовит команды через `order(:pandascore_rank)`, без него порядок непредсказуем.

---

### Шаг 8. Тесты

**`spec/lib/pandascore/client_spec.rb`**
- Stub Net::HTTP или инжектировать fake http объект
- Проверить: правильный заголовок Authorization, парсит JSON, выбрасывает `Pandascore::Error` при non-2xx

**`spec/lib/pandascore/teams_importer_spec.rb`**
- Stub client (double): `allow(client).to receive(:get).and_return([...])`
- Проверить: upsert 10 команд, возвращает 10, повторный запуск не создаёт дублей

**`spec/lib/pandascore/matches_importer_spec.rb`**
- Подготовить команды через `create_list(:pandascore_team, 10)`; stub client
- Проверить:
  - AC-7: матч с `opponents.length < 2` — пропускается, не raise
  - AC-8: матч с `winner: null` — сохраняется с `winner_id: nil`
  - AC-9: матч с `end_at: null` — пропускается, не raise
  - Идемпотентность: повторный запуск — счётчик не растёт
  - Минимальная запись команды создаётся для не-топ-10 команды

---

## Порядок выполнения

1. Миграции → `bin/rails db:migrate`
2. Обновить `Team` модель (валидация)
3. `lib/pandascore/client.rb` + `lib/pandascore/error.rb`
4. `lib/pandascore/teams_importer.rb`
5. `lib/pandascore/matches_importer.rb`
6. `lib/tasks/pandascore.rake`
7. Обновить фабрики
8. Тесты (шаги 3–5)

## Файлы для создания/изменения

| Действие | Файл |
|----------|------|
| create | `db/migrate/<ts>_add_pandascore_fields_to_teams.rb` |
| create | `db/migrate/<ts>_add_pandascore_id_to_matches.rb` |
| modify | `app/models/team.rb` |
| create | `lib/pandascore/error.rb` |
| create | `lib/pandascore/client.rb` |
| create | `lib/pandascore/teams_importer.rb` |
| create | `lib/pandascore/matches_importer.rb` |
| create | `lib/tasks/pandascore.rake` |
| create | `spec/lib/pandascore/client_spec.rb` |
| create | `spec/lib/pandascore/teams_importer_spec.rb` |
| create | `spec/lib/pandascore/matches_importer_spec.rb` |
| modify | `spec/factories/teams.rb` |
