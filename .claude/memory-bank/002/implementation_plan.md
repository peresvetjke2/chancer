# Implementation Plan: Load Team Matches (#2)

## Шаги

### 1. Миграция: добавить `hltv_id` в `matches`

Создать новую миграцию (не трогать существующие):

```ruby
# db/migrate/<timestamp>_add_hltv_id_to_matches.rb
class AddHltvIdToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :hltv_id, :integer
    add_index  :matches, :hltv_id, unique: true
  end
end
```

Запустить `bin/rails db:migrate`.

---

### 2. Скрапер `lib/scrapers/hltv/matches.rb`

По образцу `lib/scrapers/hltv/teams.rb`:

- `Scrapers::Hltv::Matches.call(team:)` → массив хэшей или `[]`
- URL: `https://www.hltv.org/results?team=<team.hltv_id>`
- CSS-селектор для ожидания: `.result-con` (блок с результатом матча)
- Период: фильтровать по `played_at >= 30.days.ago` при парсинге
- Возвращаемый хэш каждого матча:
  ```ruby
  {
    hltv_id:        Integer,   # из href="/matches/<id>/..."
    played_at:      Time,
    team1_hltv_id:  Integer,
    team1_name:     String,
    team2_hltv_id:  Integer,
    team2_name:     String,
    winner_hltv_id: Integer,
    score:          String,    # "2:1"
    tournament:     String,
    maps:           Array      # [{map_name:, score:}], [] если .mapholder отсутствует
  }
  ```
- `fetch_html`: тот же Selenium headless Chrome, что в `Teams`
- Ошибки (`Selenium::WebDriver::Error::*`, timeout) → `raise Scrapers::Hltv::Error`

**Разбор HTML (`.result-con`):**

| Данные | Селектор |
|---|---|
| `hltv_id` | `a.a-reset[href*='/matches/']` → `/matches/(\d+)/` |
| `played_at` | `.time[data-unix]` → `Time.at(val.to_i / 1000)` |
| `team1` / `team2` | `.team` блоки → `a[href*='/team/']` → `/team/(\d+)/`; имя — `.team-name` текст |
| `score` | `.result-score` текст |
| победитель | блок `.team` с классом `won` |
| `tournament` | `.event[title]` или `.event` текст |
| карты | `.mapholder` → каждый: `.mapname` + `.results-center-half-score` |

---

### 3. Rake task `lib/tasks/matches.rake`

```ruby
namespace :matches do
  desc "Load match results from HLTV for all teams"
  task load: :environment do
    Team.where.not(hltv_id: nil).each do |team|
      results = Scrapers::Hltv::Matches.call(team: team)
      next if results.empty?

      results.each do |data|
        # find or create opponent
        opponent_hltv_id = data[:team1_hltv_id] == team.hltv_id ? data[:team2_hltv_id] : data[:team1_hltv_id]
        # ... (см. шаг 4)
      end
    rescue => e
      Rails.logger.error "[matches:load] Failed for team #{team.hltv_id}: #{e.message}"
    end
  end
end
```

---

### 4. Сохранение в БД (внутри rake task)

Для каждого матча из результатов скрапера:

1. Вычислить `opponent_hltv_id` и `opponent_name` из `data`:
   ```ruby
   if data[:team1_hltv_id] == team.hltv_id
     opponent_hltv_id, opponent_name = data[:team2_hltv_id], data[:team2_name]
   else
     opponent_hltv_id, opponent_name = data[:team1_hltv_id], data[:team1_name]
   end
   ```
2. `Team.find_or_create_by(hltv_id: opponent_hltv_id) { |t| t.name = opponent_name }` — создать минимальную запись оппонента если нет в БД
3. Разрешить `team1_id`, `team2_id`, `winner_id` через `Team.find_by(hltv_id: ...)`
4. `Match.upsert({ hltv_id:, played_at:, team1_id:, team2_id:, winner_id:, score:, tournament: }, unique_by: :hltv_id)`
5. Сохранить карты: найти матч по `hltv_id`, сделать `match.map_results.delete_all`, затем `MapResult.insert_all(maps_data)` (у `map_results` нет уникального индекса, поэтому `upsert_all` не применять — только delete + insert)

> `Team` валидирует `hltv_id: presence: true, uniqueness: true` — `find_or_create_by(hltv_id:)` с блоком задаёт `name`, этого достаточно.

---

### 5. Fixture для тестов

Создать `spec/fixtures/hltv_match_results.html` — реальный (или упрощённый) HTML страницы `/results?team=<id>` с:
- минимум 2 матчами в пределах 30 дней
- хотя бы 1 матч с картами (`.mapholder`)
- хотя бы 1 матч без карт

---

### 6. RSpec: скрапер `spec/lib/scrapers/hltv/matches_spec.rb`

По образцу `spec/lib/scrapers/hltv/teams_spec.rb`:

```ruby
describe "#call" do
  before { allow_any_instance_of(described_class).to receive(:fetch_html).and_return(html) }

  it "returns an array of hashes" do ...  end
  it "parses first match correctly" do
    expect(result.first).to include(hltv_id: <val>, score: <val>, maps: <val>)
  end
  it "returns [] for matches older than 30 days" do ... end
end

context "when Selenium times out" do
  it "raises Scrapers::Hltv::Error" do ... end
end
```

---

### 7. RSpec: rake task `spec/tasks/matches_spec.rb`

Настройка загрузки rake-задачи:

```ruby
require "rails_helper"
require "rake"

RSpec.describe "matches:load" do
  before(:all) do
    Rails.application.load_tasks  # загружает все .rake из lib/tasks
  end

  before do
    Rake::Task["matches:load"].reenable
  end
  # ...
end
```

- Интеграционный тест с реальной БД (не мокать AR)
- Мокать `Scrapers::Hltv::Matches.call` → возвращает fixture-данные (хэши с `team1_name`, `team2_name` и т.д.)
- Проверить:
  - `Match.count` увеличился
  - Повторный запуск — `count` стабилен (upsert)
  - `match.map_results` создан если были карты
  - Команда без `hltv_id` не передаётся в scraper (проверить через `expect(Scrapers::Hltv::Matches).not_to receive(:call)`)

---

## Порядок выполнения

1. Миграция + `bin/rails db:migrate`
2. Fixture HTML
3. Scraper `lib/scrapers/hltv/matches.rb`
4. Spec скрапера (TDD-стиль: fixture → парсинг)
5. Rake task
6. Spec rake task
7. Ручная проверка: `bundle exec rake matches:load`

## Файлы для создания

| Файл | Тип |
|---|---|
| `db/migrate/<ts>_add_hltv_id_to_matches.rb` | новый |
| `lib/scrapers/hltv/matches.rb` | новый |
| `lib/tasks/matches.rake` | новый |
| `spec/fixtures/hltv_match_results.html` | новый |
| `spec/lib/scrapers/hltv/matches_spec.rb` | новый |
| `spec/tasks/matches_spec.rb` | новый |

## Файлы для изменения

| Файл | Изменение |
|---|---|
| `app/models/match.rb` | (нет изменений, `hltv_id` появится автоматически через миграцию) |
