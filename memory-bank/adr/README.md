---
title: Architecture Decision Records Index
doc_kind: adr
doc_function: index
purpose: Навигация по ADR проекта. Читать, чтобы найти уже принятые решения или завести новый ADR по шаблону.
derived_from:
  - ../dna/governance.md
  - ../flows/templates/adr/ADR-XXX.md
status: active
audience: humans_and_agents
---

# Architecture Decision Records Index

Каталог `memory-bank/adr/` хранит instantiated ADR проекта.

- Заводи новый ADR из шаблона [`../flows/templates/adr/ADR-XXX.md`](../flows/templates/adr/ADR-XXX.md).
- Держи в этом каталоге только реальные decision records, а не заметки или черновые исследования.
- Если ADR пока нет, этот индекс остается пустым и служит ожидаемой точкой размещения для будущих решений.

## Naming

- Формат файла: `ADR-XXX-short-decision-name.md`
- Нумерация монотонная и не переиспользуется
- Заголовок файла должен совпадать с `title` во frontmatter

## Records

- [`ADR-003: PandaScore Free API Attribute Scope`](ADR-003-pandascore-free-api-attribute-scope.md) — `decision_status: proposed`; перечень сущностей и атрибутов PandaScore, допустимых для free plan, с обязательными source links.

## Archived

AI-агент не имеет право читать эти документы без явного требования пользователя!

- [`ADR-002: CS2 Attribute-Level Source Matrix`](ADR-002-cs2-attribute-source-matrix.md) — архивирован, `decision_status: rejected`; не читать как действующее или рекомендуемое решение.
- [`ADR-001: CS2 Data Acquisition Source Strategy`](ADR-001-cs2-data-acquisition-source-strategy.md) — архивирован, `decision_status: rejected`; не читать как действующее или рекомендуемое решение.

## Statuses

- `proposed` — решение сформулировано, но еще не принято
- `accepted` — решение принято и считается canonical input для downstream-документов
- `superseded` — решение заменено другим ADR
- `rejected` — решение рассмотрено и отклонено
