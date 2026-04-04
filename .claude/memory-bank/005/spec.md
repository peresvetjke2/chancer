# Spec: Расширение данных PandaScore (задача 005)

Related: [.claude/memory-bank/005/brief.md](.claude/memory-bank/005/brief.md)

## Цель

Устранить пробелы в импорте PandaScore, которые блокируют аналитические задачи 007–009.
Реализация — две новые миграции и правки в `MatchesImporter` / `TeamsImporter`.

---

## Изменения схемы

### 1. `map_results` — добавить `pandascore_id` и `winner_team_id`

Текущие поля: `match_id`, `map_name`, `score`.

```ruby
add_column :map_results, :pandascore_id,  :integer   # game["id"], ключ дедупликации
add_column :map_results, :winner_team_id, :bigint
add_foreign_key :map_results, :teams, column: :winner_team_id
add_index :map_results, :pandascore_id, unique: true
add_index :map_results, :winner_team_id
```

Модель: добавить `belongs_to :winner_team, class_name: "Team", optional: true`.

Дедупликация при повторных импортах — по `pandascore_id`, а не по `(match_id, map_name)`.  
Причина: карта может повторяться (вечные переигровки), а game.id уникален на стороне API.

---

### 2. `matches` — добавить поля из API

Текущие поля: `pandascore_id`, `team1_id`, `team2_id`, `winner_id`, `score`,
`tournament`, `played_at`, `hltv_id`.

```ruby
add_column :matches, :begin_at,         :datetime
add_column :matches, :end_at,           :datetime
add_column :matches, :match_type,       :string    # "best_of_1", "best_of_3", "best_of_5"
add_column :matches, :status,           :string    # "finished", "running", "not_started"
add_column :matches, :league_id,        :bigint
add_column :matches, :league_name,      :string
add_column :matches, :serie_id,         :bigint
add_column :matches, :serie_name,       :string
add_column :matches, :tournament_id,    :bigint
add_column :matches, :tournament_name,  :string    # вместо существующего `tournament`
```

> `tournament` уже хранит строку — переименовываем в `tournament_name` для единообразия.
> Существующую колонку не трогаем: добавляем `tournament_name` как новую.
> Колонка `tournament` остаётся в схеме до завершения задач 007–009; удаление — отдельная задача после их мёржа.

Маппинг из API:

| Колонка | API-поле |
|---------|----------|
| `begin_at` | `match["begin_at"]` |
| `end_at` | `match["end_at"]` |
| `match_type` | `match["match_type"]` |
| `status` | `match["status"]` |
| `league_id` | `match.dig("league", "id")` |
| `league_name` | `match.dig("league", "name")` |
| `serie_id` | `match.dig("serie", "id")` |
| `serie_name` | `match.dig("serie", "name")` |
| `tournament_id` | `match.dig("tournament", "id")` |
| `tournament_name` | `match.dig("tournament", "name")` |

> `played_at` (существующая колонка) дублирует `end_at` — оба хранят `match["end_at"]`.
> В рамках этой задачи `played_at` не трогаем и не заполняем повторно.
> Удаление `played_at` — отдельный рефакторинг после миграции зависимых задач.

`league_id` / `serie_id` нужны для дедупликации: два турнира могут иметь одинаковое
`name` в разные сезоны.

---

### 3. `teams` — добавить `acronym`, `image_url`, `slug`; исправить `pandascore_rank`

Текущие поля: `pandascore_id`, `pandascore_rank`, `name`, `region`, `hltv_id`, `hltv_rank`.

```ruby
add_column :teams, :acronym,   :string
add_column :teams, :image_url, :string
add_column :teams, :slug,      :string
```

Маппинг из API (`/csgo/teams`):

| Колонка | API-поле |
|---------|----------|
| `acronym` | `t["acronym"]` |
| `image_url` | `t["image_url"]` |
| `slug` | `t["slug"]` |
| `pandascore_rank` | `t["ranking"]` (не `i + 1`) |

---

### 4. `players` — добавить `pandascore_id`

Текущие поля: `name`, `role`, `team_id`.  
Поле `role` уже есть в схеме — при импорте просто заполнять его из API.

```ruby
add_column :players, :pandascore_id, :integer
add_index :players, :pandascore_id, unique: true
```

Игроки приходят в ответе `/csgo/teams` в поле `players[]`:

```json
{ "id": 11234, "name": "s1mple", "role": "rifler" }
```

`TeamsImporter` должен upsert-ить игроков по `pandascore_id` при импорте команды.  
Модель: добавить `validates :pandascore_id, uniqueness: true, allow_nil: true`.

---

## Изменения в импортерах

### `TeamsImporter`

1. Добавить `acronym`, `image_url`, `slug` в `upsert_all` строки.
2. Исправить `pandascore_rank`: брать `t["ranking"]` вместо `i + 1`; nil если отсутствует.
3. После upsert команд — upsert игроков из `t["players"]`:

```ruby
team = Team.find_by!(pandascore_id: t["id"])  # один find_by per team, не внутри players-цикла
Array(t["players"]).each do |p|
  Player.find_or_create_by(pandascore_id: p["id"]) do |player|
    player.name    = p["name"]
    player.role    = p["role"]
    player.team_id = team.id
  end
end
```

> **Ограничение:** блок `find_or_create_by` выполняется только при создании.
> Если игрок уже есть в БД, его `role` и `team_id` при повторном импорте не обновятся.
> Это допустимо для задачи 005 — трансферы игроков выходят за её scope.
> Если обновление при трансфере понадобится, нужен отдельный `upsert_all` по игрокам.

### `MatchesImporter`

1. Добавить в `Match.upsert`: `begin_at`, `end_at`, `match_type`, `status`,
   `league_id`, `league_name`, `serie_id`, `serie_name`, `tournament_id`, `tournament_name`.
2. Добавить все новые поля в `update_only`.
3. После upsert матча — upsert карт из `match["games"]`, пропуская `map: null`:

```ruby
saved_match = Match.find_by!(pandascore_id: match["id"])

Array(match["games"]).each do |game|
  next if game["map"].nil?   # несыгранная позиция в bo3/bo5

  winner_ps_id = game.dig("winner", "id")
  winner_team  = winner_ps_id ? Team.find_by(pandascore_id: winner_ps_id) : nil

  results = game["results"] || []
  r1    = results.find { |r| r["team_id"] == match.dig("opponents", 0, "opponent", "id") }
  r2    = results.find { |r| r["team_id"] == match.dig("opponents", 1, "opponent", "id") }
  score = (r1 && r2) ? "#{r1["score"]}-#{r2["score"]}" : nil

  MapResult.find_or_create_by(pandascore_id: game["id"]) do |mr|
    mr.match_id      = saved_match.id
    mr.map_name      = game.dig("map", "name")
    mr.score         = score
    mr.winner_team_id = winner_team&.id
  end
end
```

> Дедупликация карт — по `pandascore_id` (game["id"]), не по `(match_id, map_name)`.

---

## Порядок реализации

> Все изменения намеренно объединены в одну задачу: поля нужны задачам 007–009 одновременно,
> и разбиение создаст зависимость между PR-ами. Альтернативный вариант — 005a/005b — не выбран.

1. **Миграция** — все новые колонки: `teams` (`acronym`, `image_url`, `slug`), `matches` (новые поля включая `tournament_id`), `map_results` (`pandascore_id`, `winner_team_id`), `players` (`pandascore_id`).
2. Обновить модели (`belongs_to`, `validates`).
3. Обновить `TeamsImporter` + тесты.
4. Обновить `MatchesImporter` + тесты.

---

## Что изменить в тестах

### `spec/lib/pandascore/teams_importer_spec.rb`
- Добавить в fixture: `acronym`, `image_url`, `slug`, `ranking`, `players[]` (с `id`, `name`, `role`).
- Проверить, что `pandascore_rank` берётся из `ranking`, а не из позиции в массиве.
- Проверить, что игроки создаются с корректными `pandascore_id` и `role`.
- Проверить, что повторный импорт не дублирует игроков.

### `spec/lib/pandascore/matches_importer_spec.rb`
- Добавить в fixture: `begin_at`, `end_at`, `match_type`, `status`, `league` (с `id` и `name`), `serie` (с `id` и `name`), `tournament` (с `name`).
- Добавить `games[]` с тремя элементами: два сыгранных (с `id`, `map`, `winner`, `results`) и один `{ "map": null, "winner": null, "results": [] }`.
- Проверить, что матч сохраняет все новые поля.
- Проверить, что создаются ровно 2 `MapResult` (третий пропускается).
- Проверить, что `MapResult` содержит корректные `pandascore_id`, `winner_team_id`, `score`.
- Проверить, что повторный импорт не дублирует карты.

---

## Инварианты

- `map_results.pandascore_id`: уникальный индекс, NOT NULL при создании через импорт (application-level; `null: false` на уровне БД не устанавливается).
- `players.pandascore_id`: уникальный индекс, допускает NULL (для ручных записей).
- `MapResult` создаётся даже если `score` вычислить невозможно (`score = nil`).

## Транзакционность

`TeamsImporter` не оборачивает upsert команд и создание игроков в одну транзакцию.
Частичный успех (команды без игроков) допустим — повторный импорт доберёт игроков.

Аналогично `MatchesImporter`: если создание `MapResult` упадёт, `Match` остаётся в БД.
Частичный успех допустим — повторный импорт доберёт карты.

## Граничные случаи

| Ситуация | Ожидаемое поведение |
|----------|---------------------|
| `games` отсутствует или пустой | Карты не создаются, импорт не падает |
| `game["map"]` = null | Карта пропускается — это нормальная позиция в bo3/bo5 |
| `winner` карты не найден в БД | `winner_team_id` = nil, запись создаётся |
| `ranking` = null у команды | `pandascore_rank` = nil |
| `players` отсутствует в ответе | Игроки не создаются, импорт не падает |
| `league` / `serie` = null | `league_id`, `league_name` и т.д. = nil |
| Повторный импорт того же матча | `Match` upsert-ится; карты дедуплицируются по `pandascore_id` |
| Два турнира с одинаковым `serie_name` | Различаются по `serie_id` |
| `find_by!` после upsert не находит запись (`RecordNotFound`) | Исключение пробрасывается наверх; импорт прерывается |
