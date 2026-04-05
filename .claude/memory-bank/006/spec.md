# Spec: Bulk-импорт истории матчей (задача 006)

Related: [.claude/memory-bank/006/brief.md](.claude/memory-bank/006/brief.md)

## Цель

Наполнить БД всеми CS2-матчами за последние 3 месяца без ограничения в 100 записей,
получить полный список `pandascore_id` команд-участников, обеспечить идемпотентность повторных запусков.

---

## Что меняется

Существующий `MatchesImporter` не трогается — он работает по старой логике (top-10 команд, 7 дней).

Добавляется **новый класс** `Pandascore::BulkMatchesImporter` и **новая rake-задача**.

---

## Новый класс `Pandascore::BulkMatchesImporter`

### Интерфейс

```ruby
importer = Pandascore::BulkMatchesImporter.new(client: client)
team_ids  = importer.call(start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 4, 5))
# => [101, 202, 303, ...]   # Array<Integer> — pandascore_id команд
```

- `start_date`, `end_date` — тип `Date` (не `Time`; передаётся в API как `YYYY-MM-DD`).
- Возвращаемое значение — массив уникальных `pandascore_id` всех команд, участвовавших
  хотя бы в одном матче за период. Дубликаты устраняются до возврата.

### Алгоритм

```
page = 1
team_ids = Set.new

loop do
  matches = client.get("/csgo/matches/past",
    "range[begin_at]" => "#{start_date},#{end_date}",
    "page[size]"      => 100,
    "page[number]"    => page
  )

  break if matches.empty?

  matches.each do |match|
    # пропускаем некорректные матчи — те же проверки, что в MatchesImporter
    next if match["opponents"].length < 2
    next if match["end_at"].nil?

    # сохраняем матч (reuse существующей логики через приватный метод)
    import_match(match)

    # собираем pandascore_id команд
    match["opponents"].each do |opp|
      id = opp.dig("opponent", "id")
      team_ids << id if id
    end
  end

  page += 1
end

team_ids.to_a
```

### Метод `import_match` (приватный)

Идентична логике `MatchesImporter#call` для одного матча:
- `find_or_create_minimal_team` для каждого из двух оппонентов
- `Match.upsert` со всеми полями (`pandascore_id`, `team1_id`, `team2_id`, `winner_id`,
  `score`, `tournament`, `played_at`, `begin_at`, `end_at`, `match_type`, `status`,
  `league_id`, `league_name`, `serie_id`, `serie_name`, `tournament_id`, `tournament_name`)
- upsert карт из `match["games"]` по `pandascore_id` (пропуск при `map: nil` и `id: nil`)

**Вычисление `score`** — строка вида `"#{team1_score}-#{team2_score}"`, формируется из
`match["results"]` по `team_id` оппонентов; `nil` если результаты отсутствуют или неполны.
Пример: `results = [{ "team_id" => 101, "score" => 2 }, { "team_id" => 202, "score" => 0 }]`
→ `score = "2-0"`.

**Вычисление `winner_id`** — берётся `match.dig("winner", "id")`, ищется через
`Team.find_by(pandascore_id: ...)`. Если `match["winner"]` равен `nil` или команда
не найдена в БД — `winner_id = nil`; матч всё равно сохраняется.

> Вместо копирования кода — рассмотреть выделение `import_match` и `find_or_create_minimal_team`
> в базовый модуль/concern. Но если это усложнит реализацию — допустимо продублировать;
> рефакторинг — отдельная задача.

---

## Rake-задача

```
bin/rails pandascore:import_history[3]
```

- Аргумент — количество месяцев истории (целое число, по умолчанию 3).
- `start_date = months.months.ago.to_date`, `end_date = Date.today`.
- Выводит: количество upsert-нутых матчей и список `pandascore_id` команд.

```ruby
namespace :pandascore do
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

    puts "Matches upserted: #{Match.count}"   # индикативное значение после импорта
    puts "Participating team pandascore_ids (#{team_ids.size}):"
    puts team_ids.sort.join(", ")
  end
end
```

Счётчик импортированных матчей внутри класса не реализуется; rake-задача выводит
`Match.count` как индикативное значение (общее количество записей в таблице на момент
завершения импорта).

---

## Риск: `range[begin_at]` может не работать

Документация подтверждает механизм `range[]`, но конкретные примеры для полей datetime
отсутствуют. **Порядок проверки:**

1. Запустить с реальным токеном и убедиться, что API возвращает матчи за нужный период.
2. Если `range[begin_at]` не фильтрует — fallback: убрать параметр, читать все страницы
   и пропускать матчи, у которых `match["begin_at"] < start_date` или
   `match["begin_at"] > end_date`. Логику перебора страниц при этом сохранить.

Решение о fallback принимается во время реализации на основе реального поведения API;
в тестах используется мок, поэтому это не блокирует написание тестов.

---

## Тесты (`spec/lib/pandascore/bulk_matches_importer_spec.rb`)

### Fixture-хелпер

```ruby
def build_match(id:, team1_id:, team2_id:, begin_at: "2026-02-01T10:00:00Z")
  {
    "id"         => id,
    "begin_at"   => begin_at,
    "end_at"     => "2026-02-01T12:00:00Z",
    "match_type" => "best_of_3",
    "status"     => "finished",
    "league"     => { "id" => 1, "name" => "L" },
    "serie"      => { "id" => 2, "name" => "S" },
    "tournament" => { "id" => 3, "name" => "T" },
    "games"      => [],
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
```

### AC-1: однострочный ответ (< 100 матчей, один запрос)

Клиент возвращает 2 матча на странице 1, пустой массив на странице 2.
Ожидается: 2 матча в БД, возвращён массив из 4 `pandascore_id` команд (без дублей).

### AC-2: пагинация

Клиент возвращает 100 матчей на странице 1, 50 матчей на странице 2, пустой на странице 3.
Ожидается: клиент вызван ровно 3 раза с нарастающим `page[number]`, 150 матчей в БД.

```ruby
expect(client).to have_received(:get).exactly(3).times
expect(Match.count).to eq(150)
```

### AC-3: возвращаемый массив — уникальные pandascore_id

Два матча с одной и той же парой команд (101 vs 202).
Ожидается: возвращается `[101, 202]` (не `[101, 202, 101, 202]`).

### AC-4: матч с `opponents < 2` пропускается

Клиент возвращает один матч с одним оппонентом.
Ожидается: `Match.count == 0`, исключение не выбрасывается.

### AC-5: матч с `end_at: nil` пропускается

Ожидается: `Match.count == 0`.

### AC-6: идемпотентность

Запуск дважды с одними и теми же данными.
Ожидается: `Match.count` и `MapResult.count` не меняются после второго вызова.

### AC-7: карты

Матч с двумя сыгранными картами и одной `map: nil`.
Ожидается: 2 `MapResult` в БД.

### AC-8: пустой первый ответ — ноль итераций

Клиент возвращает `[]` на первой же странице.
Ожидается: клиент вызван 1 раз, метод возвращает `[]`, ни одного матча не создано.

---

## Граничные случаи

| Ситуация | Ожидаемое поведение |
|----------|---------------------|
| `range[begin_at]` не фильтрует | Матчи вне диапазона игнорируются через fallback-фильтрацию по `begin_at` в ответе |
| `opponent["id"]` = nil | Команда не добавляется в результирующий список, матч всё равно обрабатывается |
| Один из двух оппонентов уже есть в БД | `find_or_create_by` не создаёт дубль |
| Повторный запуск при расширении горизонта (добавляем 4-й месяц) | Старые матчи upsert-ятся без изменений; новые добавляются |
| Очень большой период (N > 100 страниц) | Пагинация продолжается до первого пустого ответа |

---

## Инварианты

- `BulkMatchesImporter#call` всегда возвращает `Array` (пустой, если матчей нет).
- `pandascore_id` в возвращаемом массиве уникальны.
- Уже существующие в БД матчи upsert-ятся (не дублируются).
- Метод не изменяет глобальное состояние `MatchesImporter`.
- Исключения из `client.get` не перехватываются — ошибка всплывает к вызывающему коду
  (rake-задаче). Частично загруженные страницы остаются в БД; повторный запуск доберёт
  недостающие.

---

## Что НЕ входит в scope

- Изменение существующего `MatchesImporter`
- Детали команд (task 013 получает список `pandascore_id` как входные данные)
- Фильтрация по `filter[team_id]` — берём все матчи за период
- Реализация auth
- Добавление новых гемов
