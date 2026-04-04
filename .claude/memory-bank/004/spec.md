# Спецификация: Интеграция с PandaScore API (CS2)

Source: `.claude/memory-bank/004/brief.md`

## Контекст

Текущая схема БД ориентирована на HLTV: в таблице `teams` есть `hltv_id` и `hltv_rank`, но нет идентификаторов PandaScore. PandaScore предоставляет официальный REST API для CS2 с бесплатным планом (1 000 запросов/час). Цель задачи — убедиться, что API доступен, данные приходят в ожидаемом формате, и корректно ложатся в существующую схему.

Стек: Rails 8, PostgreSQL 15, RSpec. Новые гемы — только по явному согласованию.

---

## Инварианты

- `pandascore_id` уникален в таблицах `teams` и `matches` (DB UNIQUE constraint)
- FR-1 (загрузка команд) всегда выполняется до FR-2 (загрузка матчей)
- Матч не сохраняется, если нельзя разрешить обоих участников (см. FR-2)
- Обработка одного матча дважды идемпотентна — upsert по `pandascore_id`

---

## Функциональные требования

### FR-1. Загрузка топ-10 команд CS2 с рейтингами

- Получить топ-10 команд по рейтингу CS2 через PandaScore API
- Сохранить/обновить записи в таблице `teams`: `name`, `region`, `pandascore_id` (новое поле, integer), `pandascore_rank` (новое поле, integer) = `team.ranking` из PandaScore (позиция в топ-листе). Поле `hltv_rank` не трогать
- При повторном запуске — обновлять существующие записи (upsert по `pandascore_id`), не дублировать

### FR-2. Загрузка матчей за последнюю неделю

- Для каждой из топ-10 команд получить завершённые матчи за последние 7 дней — только первую страницу API (≤ 25 матчей за 7 дней у одной команды; подгрузка следующих страниц — вне scope)
- Сохранить/обновить записи в таблице `matches`: `team1_id`, `team2_id`, `winner_id`, `score`, `tournament`, `played_at`, `pandascore_id` (новое поле, integer)
- При повторном запуске — не дублировать матчи (upsert по `pandascore_id`). Матч, у которого обе команды входят в топ-10, будет встречен дважды — upsert делает обработку идемпотентной
- Если одна из команд матча не входит в топ-10 и не существует в БД — создать минимальную запись команды (только `pandascore_id` и `name`)
- Если `match.opponents.length < 2` (бай, незаполненный матч) — пропустить матч, залогировать `warn` с `match.id`
- Если `match.winner` равен `null` — сохранять `winner_id: nil` (ничья или технический результат)
- Если `match.tournament` равен `null` — сохранять `tournament: nil`
- Если `match.end_at` равен `null` — пропустить матч, залогировать `warn` с `match.id`

### FR-3. Ручной запуск загрузки

- Загрузку можно запустить rake-задачей: `bin/rails pandascore:import`
- Задача последовательно выполняет FR-1, затем FR-2
- Результат выводится в stdout: количество команд и матчей, сохранённых/обновлённых

---

## Нефункциональные требования

- **NFR-1. Без обхода защиты.** Только официальный REST API с токеном в заголовке `Authorization: Bearer <token>`. Без Selenium, без парсинга HTML.
- **NFR-2. Rate limiting.** Между последовательными HTTP-запросами к API — пауза не менее 1 секунды, чтобы не превысить лимит 1 000 запросов/час. Ожидаемое время полного импорта: ~11–15 секунд (11 запросов × ≥1 сек).
- **NFR-3. Конфигурация токена.** API-токен берётся из переменной окружения `PANDASCORE_API_TOKEN`. Если переменная не задана — задача вызывает `abort "PANDASCORE_API_TOKEN is not set"` и завершается с кодом выхода 1.
- **NFR-4. Наблюдаемость.** Логировать через `Rails.logger`:
  - `info`: начало и конец каждого импортёра (`TeamsImporter`, `MatchesImporter`), количество upsert-записей по итогу каждого импортёра
  - `warn`: пропущенный матч (см. FR-2: `opponents.length < 2`, `end_at: null`) с указанием `match.id`
  - `error`: статус-код и URL при HTTP-ошибке
- **NFR-5. Тестируемость.** HTTP-запросы к PandaScore в тестах заглушаются через WebMock/VCR-кассеты или stub-объекты — без реальных сетевых запросов.
- **NFR-6. Поведение при HTTP-ошибке.** При ответе non-2xx или timeout — залогировать ошибку (статус-код и URL) и прервать задачу с ненулевым кодом выхода. Частичный сбой (ошибка при запросе матчей одной из команд) также прерывает всю задачу. Retry не предусмотрен.

---

## Критерии приёмки

| # | Критерий |
|---|----------|
| AC-1 | `bin/rails pandascore:import` завершается с кодом 0 и выводит счётчики команд и матчей |
| AC-2 | После запуска в БД есть ≥ 10 команд с заполненными `pandascore_id`, `name`, `pandascore_rank` |
| AC-3 | После запуска в БД есть матчи с `played_at` в диапазоне последних 7 дней |
| AC-4 | Повторный запуск не создаёт дублей команд и матчей (количество записей не растёт) |
| AC-5 | При отсутствии `PANDASCORE_API_TOKEN` задача выводит `"PANDASCORE_API_TOKEN is not set"` и завершается с кодом 1 |
| AC-6 | Юнит-тесты API-клиента проходят без реальных сетевых запросов |
| AC-7 | Матч с `opponents.length < 2` пропускается и не вызывает исключение |
| AC-8 | Матч с `winner: null` сохраняется с `winner_id: nil` |
| AC-9 | Матч с `end_at: null` пропускается и не вызывает исключение |

---

## Архитектурное решение

### Миграции

Добавить поля к существующим таблицам (новые миграции, существующие не трогать):

```
teams:   pandascore_id (integer, unique, null: true)
teams:   pandascore_rank (integer, null: true)
matches: pandascore_id (integer, unique, null: true)
```

### Новые компоненты

```
lib/pandascore/
  client.rb            # HTTP-клиент: авторизация, rate limiting, обработка ошибок
  teams_importer.rb    # FR-1: получить топ-10 команд, upsert в teams
  matches_importer.rb  # FR-2: получить матчи за неделю, upsert в matches

lib/tasks/
  pandascore.rake      # bin/rails pandascore:import
```

### Используемые API-эндпоинты PandaScore

- `GET /csgo/teams?sort=ranking&page[size]=10` — топ-10 команд (поле `ranking` содержит позицию в рейтинге)
- `GET /csgo/matches/past?filter[opponent_id]=<id>&range[end_at]=<from>,<to>` — завершённые матчи команды за период (первая страница)

### Маппинг полей

| PandaScore | БД | Обработка null / edge cases |
|---|---|---|
| `team.id` | `teams.pandascore_id` (integer) | — |
| `team.name` | `teams.name` | — |
| `team.location` | `teams.region` | сохранять `nil` |
| `team.ranking` | `teams.pandascore_rank` | — |
| `match.id` | `matches.pandascore_id` (integer) | — |
| `match.opponents[0].opponent` | `matches.team1_id` (по `pandascore_id`) | если `length < 2` — пропустить матч |
| `match.opponents[1].opponent` | `matches.team2_id` (по `pandascore_id`) | если `length < 2` — пропустить матч |
| `match.winner` | `matches.winner_id` (по `pandascore_id`) | сохранять `nil` |
| `match.results`: найти элемент, где `team_id` совпадает с `team1_id`, взять его `score`; аналогично для `team2_id` | `matches.score` (формат `"X-Y"`) | если `results.length < 2` или элемент не найден — сохранять `nil` |
| `match.tournament.name` | `matches.tournament` | сохранять `nil` |
| `match.end_at` | `matches.played_at` | если `null` — пропустить матч |

---

## Out of scope

- Загрузка статистики игроков (`player_stats`) — отдельная задача
- Загрузка результатов по картам (`map_results`) — отдельная задача
- Автоматический (cron) запуск — только ручной
- Матчи глубже одной недели
- Команды за пределами топ-10
- Retry при HTTP-ошибках
- Пагинация (загрузка страниц 2+)
