---
title: "FT-001: Загрузка матчей команды CS2 за период"
doc_kind: feature
doc_function: canonical
purpose: "Rake task + importer для загрузки матчей и карт (MapResult) конкретной команды CS2 из PandaScore API за заданный диапазон дат."
derived_from:
  - ../../domain/problem.md
  - ../../domain/architecture.md
status: draft
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-001: Загрузка матчей команды CS2 за период

## What

### Problem

Текущие importers загружают матчи либо для топ-10 команд целиком (`MatchesImporter`, последние 7 дней), либо пакетно для всех команд за произвольный период (`BulkMatchesImporter`). Нет инструмента, позволяющего целенаправленно загрузить историю матчей одной конкретной команды за произвольный период — что необходимо для точечного обновления данных, отладки и аналитики.

### Scope

- `REQ-01` Rake task принимает slug команды и диапазон дат (start_date, end_date в формате YYYY-MM-DD), загружает все завершённые матчи этой команды из PandaScore API и сохраняет их в БД.
- `REQ-02` Для каждого матча загружаются и сохраняются связанные карты (`MapResult`), включая счёт и победителя карты.
- `REQ-03` Команда ищется в БД по slug; если команда не найдена — задача завершается с понятным сообщением об ошибке.

### Non-Scope

- `NS-01` Нет изменений в схеме БД — используются существующие модели `Match`, `MapResult`, `Team`.
- `NS-02` Нет UI-компонентов и изменений в чат-интерфейсе.
- `NS-03` Нет новых Ruby-гемов.
- `NS-04` Загрузка игроков и их статистики (`PlayerStat`) не входит в эту фичу.
- `NS-05` Фоновые задачи (Solid Queue) не используются — только синхронный Rake task.

### Constraints / Assumptions

- `ASM-01` Команда уже импортирована в БД через `rake pandascore:import` и имеет корректный `pandascore_id`.
- `CON-01` Rate limit PandaScore 1000 req/час на бесплатном плане — `sleep 1` после каждого HTTP-запроса обязателен (канонический паттерн проекта).
- `CON-02` Новые Ruby-гемы добавлять нельзя (`PCON-04`).
- `CON-03` Существующие миграции БД не изменяются (`PCON-05`).

## How

### Solution

Новый класс `Pandascore::TeamMatchesImporter` принимает `client:`, `pandascore_team_id:`, `start_date:`, `end_date:` и постранично запрашивает `/csgo/matches` с фильтрами `filter[opponent_id]` и `range[begin_at]`. Логика upsert матчей и карт переиспользует паттерн из `BulkMatchesImporter`. Rake task `pandascore:import_team[slug,start_date,end_date]` выполняет lookup команды по slug, затем вызывает importer и выводит итог.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `lib/pandascore/team_matches_importer.rb` | code | Новый importer для загрузки матчей одной команды |
| `lib/tasks/pandascore.rake` | code | Новый Rake task `pandascore:import_team` |

### Flow

1. Пользователь запускает `rake pandascore:import_team[natus-vincere,2025-01-01,2025-03-31]`.
2. Rake task ищет `Team.find_by(slug: slug)` в БД; если не найдена — `abort` с сообщением.
3. Rake task создаёт `Pandascore::TeamMatchesImporter.new(client:, pandascore_team_id: team.pandascore_id, start_date:, end_date:)` и вызывает `import`.
4. Importer постранично запрашивает `/csgo/matches` с фильтром по team id и диапазону дат. После каждого HTTP-запроса — `sleep 1`.
5. Для каждого матча: upsert `Match` (`unique_by: :pandascore_id`), upsert обеих команд-оппонентов, upsert `MapResult`-ов.
6. Rake task выводит количество обработанных матчей и карт.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | CLI: `rake pandascore:import_team[slug,start_date,end_date]` | Пользователь → Rake task | slug — поле `Team#slug`; даты в формате YYYY-MM-DD |
| `CTR-02` | PandaScore API `/csgo/matches?filter[opponent_id]=<id>&range[begin_at]=<start,end>&filter[status]=finished` | `TeamMatchesImporter` → PandaScore | Пагинация через `page` / `per_page=100` |

### Failure Modes

- `FM-01` Команда с указанным slug не найдена в БД → Rake task завершается с `abort "Team not found: #{slug}"`.
- `FM-02` PandaScore API возвращает пустой список за период → import завершается успешно, 0 матчей (не ошибка).
- `FM-03` PandaScore API возвращает не-2xx → `Pandascore::Error` поднимается наверх и выводится стандартно Rails (существующий паттерн).

## Verify

### Exit Criteria

- `EC-01` `rake pandascore:import_team[slug,start_date,end_date]` успешно завершается для известной команды и периода с реальными матчами: в БД появляются соответствующие записи `Match` и `MapResult`.
- `EC-02` Запуск с неизвестным slug завершается с понятным сообщением об ошибке и ненулевым кодом выхода.
- `EC-03` Повторный запуск с теми же аргументами не создаёт дублей (idempotency через upsert).

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `CON-01`, `CTR-01`, `CTR-02`, `FM-01`, `FM-03` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-01`, `CTR-02`, `FM-02` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `FM-01` | `EC-02`, `SC-02` | `CHK-02` | `EVID-02` |

### Acceptance Scenarios

- `SC-01` Happy path: запуск `rake pandascore:import_team[<existing_slug>,<start>,<end>]` для команды с матчами в указанный период → задача завершается успешно, в `matches` и `map_results` появляются новые записи с корректным `pandascore_id`, повторный запуск не создаёт дублей.
- `SC-02` Unknown slug: запуск `rake pandascore:import_team[unknown-slug,2025-01-01,2025-03-31]` → задача завершается с exit code != 0 и сообщением `"Team not found: unknown-slug"`, БД не изменяется.
- `SC-03` Пустой период: запуск для существующей команды, у которой нет матчей в указанный период → задача завершается успешно, выводит "0 matches imported", БД не изменяется.

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-03`, `SC-01`, `SC-03` | `bundle exec rspec spec/lib/pandascore/team_matches_importer_spec.rb` | All examples pass | `artifacts/ft-001/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-02` | `bundle exec rspec spec/lib/pandascore/team_matches_importer_spec.rb` + rake task integration test | Abort scenario covered | `artifacts/ft-001/verify/chk-02/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-001/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-001/verify/chk-02/` |

### Evidence

- `EVID-01` RSpec output для `TeamMatchesImporter` — все сценарии зелёные; скриншот или log-файл.
- `EVID-02` RSpec output или manual run, подтверждающий abort при неизвестном slug.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | RSpec output (happy path + idempotency + empty period) | verify-runner / human | `artifacts/ft-001/verify/chk-01/` | `CHK-01` |
| `EVID-02` | RSpec output или terminal log (unknown slug abort) | verify-runner / human | `artifacts/ft-001/verify/chk-02/` | `CHK-02` |
