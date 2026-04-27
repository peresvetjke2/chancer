---
title: "ADR-004: HLTV Enrichment And Controlled Acquisition Strategy"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует, какие CS2-атрибуты HLTV потенциально может обогащать сверх PandaScore baseline, а также policy и эксплуатационную стратегию для работы с HLTV."
derived_from:
  - ../domain/cs2-data-attributes.md
  - ./ADR-003-pandascore-free-api-attribute-scope.md
status: draft
decision_status: proposed
date: 2026-04-27
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-004: HLTV Enrichment And Controlled Acquisition Strategy

## Контекст

`ADR-003` зафиксировал узкий, доказуемый baseline structured-data contract на базе `PandaScore free API`. Этот baseline полезен, но не покрывает значительную часть canonical-атрибутов из `memory-bank/domain/cs2-data-attributes.md`.

`HLTV` выглядит естественным кандидатом на enrichment, потому что публично показывает большое кол-во нужных данных..

## Драйверы решения

- Базовые доменные атрибуты будут загружаться из PandaScore (см. "2.1. Связь с `memory-bank/domain/cs2-data-attributes.md`" в `ADR-003`)
- HLTV известен свой строгой anti-bot защитой, но должен быть рассмтрен в качестве слоя дополнительного обогащения данных.
- Юридическая сторона вопроса (запрос лицензий, допусков и прочее у HLTV) - вне рамок исследования.

## Рассмотренные варианты


## Решение
