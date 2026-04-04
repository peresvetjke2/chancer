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

---

## Функциональные требования

### FR-1. Загрузка топ-10 команд CS2 с рейтингами

- Получить топ-10 команд по рейтингу CS2 через PandaScore API
- Сохранить/обновить записи в таблице `teams`: `name`, `region`, `pandascore_id` (новое поле), `hltv_rank` = `team.ranking` из PandaScore (целое число, позиция в топ-листе)
- При повторном запуске — обновлять существующие записи (upsert по `pandascore_id`), не дублировать

### FR-2. Загрузка матчей за последнюю неделю

- Для каждой из топ-10 команд получить завершённые матчи за последние 7 дней
- Сохранить/обновить записи в таблице `matches`: `team1_id`, `team2_id`, `winner_id`, `score`, `tournament`, `played_at`, `pandascore_id` (новое поле)
- При повторном запуске — не дублировать матчи (upsert по `pandascore_id`)
- Если одна из команд матча не входит в топ-10 и не существует в БД — создать минимальную запись команды (только `name` и `pandascore_id`)
- Если `match.opponents.length < 2` (бай, незаполненный матч) — пропустить матч, залогировать `warn` с `match.id`
- Если `match.winner` равен `null` — сохранять `winner_id: nil` (ничья или технический результат)
- Если `match.tournament` равен `null` — сохранять `tournament: nil`

### FR-3. Ручной запуск загрузки

- Загрузку можно запустить rake-задачей: `bin/rails pandascore:import`
- Задача последовательно выполняет FR-1, затем FR-2
- Результат выводится в stdout: количество команд и матчей, сохранённых/обновлённых

---

## Нефункциональные требования

- **NFR-1. Без обхода защиты.** Только официальный REST API с токеном в заголовке `Authorization: Bearer <token>`. Без Selenium, без парсинга HTML.
- **NFR-2. Rate limiting.** Между последовательными HTTP-запросами к API — пауза не менее 1 секунды, чтобы не превысить лимит 1 000 запросов/час.
- **NFR-3. Конфигурация токена.** API-токен берётся из переменной окружения `PANDASCORE_API_TOKEN`. Если переменная не задана — задача вызывает `abort "PANDASCORE_API_TOKEN is not set"` и завершается с кодом выхода 1.
- **NFR-4. Наблюдаемость.** Логировать через `Rails.logger`:
  - `info`: начало и конец каждого импортёра (`TeamsImporter`, `MatchesImporter`), количество upsert-записей по итогу каждого импортёра
  - `warn`: пропущенный матч (см. FR-2, `opponents.length < 2`)
  - `error`: статус-код и URL при HTTP-ошибке
- **NFR-5. Тестируемость.** HTTP-запросы к PandaScore в тестах заглушаются через WebMock/VCR-кассеты или stub-объекты — без реальных сетевых запросов.
- **NFR-6. Поведение при HTTP-ошибке.** При ответе non-2xx или timeout — залогировать ошибку (статус-код и URL) и прервать задачу с ненулевым кодом выхода. Retry не предусмотрен.

---

## Критерии приёмки

| # | Критерий |
|---|----------|
| AC-1 | `bin/rails pandascore:import` завершается с кодом 0 и выводит счётчики команд и матчей |
| AC-2 | После запуска в БД есть ≥ 10 команд с заполненными `pandascore_id`, `name`, `hltv_rank` |
| AC-3 | После запуска в БД есть матчи с `played_at` в диапазоне последних 7 дней |
| AC-4 | Повторный запуск не создаёт дублей команд и матчей (количество записей не растёт) |
| AC-5 | При отсутствии `PANDASCORE_API_TOKEN` задача выводит `"PANDASCORE_API_TOKEN is not set"` и завершается с кодом 1 |
| AC-6 | Юнит-тесты API-клиента проходят без реальных сетевых запросов |
| AC-7 | Матч с `opponents.length < 2` пропускается и не вызывает исключение |
| AC-8 | Матч с `winner: null` сохраняется с `winner_id: nil` |

---

## Архитектурное решение

### Миграции

Добавить поля к существующим таблицам (новые миграции, существующие не трогать):

```
teams:   pandascore_id (string, unique, null: true)
matches: pandascore_id (string, unique, null: true)
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
- `GET /csgo/matches/past?filter[opponent_id]=<id>&range[end_at]=<from>,<to>` — завершённые матчи команды за период

### Маппинг полей

| PandaScore | БД | Обработка null |
|---|---|---|
| `team.id` | `teams.pandascore_id` | — |
| `team.name` | `teams.name` | — |
| `team.location` | `teams.region` | сохранять `nil` |
| `team.ranking` | `teams.hltv_rank` | — |
| `match.id` | `matches.pandascore_id` | — |
| `match.opponents[0].opponent` | `matches.team1_id` (по `pandascore_id`) | если `< 2` — пропустить матч |
| `match.opponents[1].opponent` | `matches.team2_id` (по `pandascore_id`) | если `< 2` — пропустить матч |
| `match.winner` | `matches.winner_id` (по `pandascore_id`) | сохранять `nil` |
| `match.results[0].score` + `[1].score` | `matches.score` (формат `"X-Y"`) | если `match.results.length < 2` или любой элемент отсутствует — сохранять `nil` |
| `match.tournament.name` | `matches.tournament` | сохранять `nil` |
| `match.end_at` | `matches.played_at` | — |

---

## Out of scope

- Загрузка статистики игроков (`player_stats`) — отдельная задача
- Загрузка результатов по картам (`map_results`) — отдельная задача
- Автоматический (cron) запуск — только ручной
- Матчи глубже одной недели
- Команды за пределами топ-10
- Retry при HTTP-ошибках
