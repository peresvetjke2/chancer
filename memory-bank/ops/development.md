---
title: Development Environment
doc_kind: engineering
doc_function: canonical
purpose: Шаблон документа для локальной разработки. Читать при адаптации setup, dev-команд и browser/database workflow под проект.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Development Environment

## Setup

Перечисли минимальную подготовку среды.

```bash
bundle install
```

## Daily Commands

```bash
bundle exec rspec
bundle exec rubocop
```

## Database And Services

Документируй только то, что действительно важно для локальной работы:

- миграции;
- пересоздание локальной БД;
- обязательные сервисы;
- seeded data;
- known pitfalls для разработчиков и агентов.

## Adoption Checklist

- [ ] указаны реальные setup-команды
- [ ] указаны реальные test/lint commands
- [ ] документирован способ определения локального URL
- [ ] перечислены локальные зависимости и сервисы
- [ ] удалены нерелевантные примеры
