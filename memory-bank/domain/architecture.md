
---
title: Architecture Patterns
doc_kind: domain
doc_function: canonical
purpose: Каноничное место для архитектурных границ проекта. Читать при изменениях, затрагивающих модули, фоновые процессы, интеграции или конфигурацию.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Architecture Patterns

## Module Boundaries

| Context | Owns | Must not depend on directly |
| --- | --- | --- |
| `lib/pandascore` | HTTP-клиент, importers — вся логика взаимодействия с PandaScore API | AR-модели напрямую, кроме как через явные upsert-методы |
| `app/models` | AR-схема, валидации, ассоциации | детали внешних API, HTTP |
| `lib/tasks` | Rake-точки входа (CLI-интерфейс для импорта) | бизнес-логику; только вызывают importer и печатают результат |
| `app/jobs` | фоновые задачи (пока пустые) | не используются для синхронного импорта |
| `lib/scrapers` | HLTV-скраппер (на паузе) | PandaScore-слой |

Правила:

- `Pandascore::Client` — единственная точка HTTP-взаимодействия с PandaScore; другие классы не делают HTTP-запросы самостоятельно.
- Importers получают инстанс `Client` через конструктор (`client:` kwarg) — зависимость явная, инъецируемая (упрощает тест).
- Rake-задачи только вызывают importer и выводят итог; никакой логики внутри.

## Concurrency And Critical Sections

На старте импорт запускается вручную через Rake (`rails pandascore:import`, `rails pandascore:import_history`). Фоновые задачи (Solid Queue) пока не задействованы.

**Текущий rate-limit pattern:**

```ruby
# Pandascore::Client#get — после каждого HTTP-запроса:
sleep 1
```

Это единственный concurrency control на текущем этапе. Цель — не превысить лимит PandaScore (1 000 req/час на бесплатном плане).

Правила:

- `sleep 1` после каждого запроса — канонический паттерн; не убирать без явного решения.
- Параллельный импорт из нескольких потоков не предусмотрен и не безопасен без дополнительного rate-limiting.
- Транзакция БД не оборачивает HTTP-запросы: upsert-ы атомарны на уровне отдельной записи (`unique_by: :pandascore_id`).

## Failure Handling And Error Tracking

**HTTP-слой:** `Pandascore::Client` логирует ошибку и поднимает `Pandascore::Error` при любом не-2xx ответе. Retry на уровне клиента отсутствует — повторный запуск Rake-задачи идемпотентен (upsert по `pandascore_id`).

**Importers:**

- `BulkMatchesImporter` и `MatchesImporter` пропускают (skip + log) отдельные матчи с `opponents < 2` или `end_at: nil` — продолжают цикл, не прерывают весь импорт.
- `MapResult` создаётся через `find_or_create_by(pandascore_id:)` — идемпотентно при повторном запуске.
- Ошибки не перехватываются внутри importers — поднимаются наверх в Rake-задачу и выводятся стандартно Rails.

**Правило:** не добавлять локальный `rescue` в importer, если единственная цель — подавить ошибку. Idempotency обеспечивается upsert-стратегией, а не retry-логикой.

## Configuration Ownership

**Schema owner:** `Pandascore::Client` — единственное место, где читается `PANDASCORE_API_TOKEN`.

**Точка входа:** Rake-задачи проверяют наличие токена явно (`abort ... if token.blank?`) и передают его в `Client.new(token:)`.

**Defaults и env:** `.env`-файл (через `dotenv-rails`); `ENV["PANDASCORE_API_TOKEN"]` — единственная обязательная переменная для импорта.

Шаги при добавлении новой конфигурации:

1. Добавить переменную в `.env` (и обновить `.env.example`, если есть).
2. Прочитать в Rake-задаче или инициализаторе; передать через конструктор — не читать `ENV` внутри lib-классов напрямую.
3. Обновить [`../ops/config.md`](../ops/config.md).
