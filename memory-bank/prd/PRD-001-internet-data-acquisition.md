---
title: "PRD-001: Internet Data Acquisition"
doc_kind: prd
doc_function: canonical
purpose: "Фиксирует продуктовую инициативу по созданию единого слоя сбора данных из интернета для CS2-аналитики: документированный API-baseline, controlled enrichment, нормализация, контроль качества и управляемое обновление."
derived_from:
  - ../domain/problem.md
status: draft
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
---

# PRD-001: Internet Data Acquisition

## Problem

Чтобы строить надёжную аналитику и прогнозы по матчам CS2, продукту нужен устойчивый слой сбора данных из интернета. Сейчас project-wide контекст фиксирует важность истории матчей, составов, рейтингов и статистики игроков, но не определяет продуктовый scope отдельной инициативы по acquisition layer.

Проблема состоит в том, что данные нужны из нескольких внешних источников с разной природой доступа, но их допустимость и надёжность различаются. Часть structured baseline можно получать из документированного API, а часть потенциально ценных сигналов доступна только как ограниченное enrichment-поверхность. Без единого capability-слоя система не может последовательно отвечать на вопросы:

- какие источники считаются допустимыми для baseline, а какие допустимы только как controlled enrichment;
- какие сущности и атрибуты обязаны покрываться в baseline scope в рамках подтверждённого free/API contract;
- как отличать пригодные данные от частичных, устаревших или конфликтующих.

Этот PRD сознательно рассматривает тему интернет-сбора данных как отдельную инициативу и не наследует текущие importers, rake tasks или существующие интеграции как продуктовую рамку. Текущая реализация не является обязательным ограничением; reuse или redesign определяются downstream design.

## Users And Jobs

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| `better-user` | Получить прогноз и аналитику, основанные на свежих и полных данных | Данные в продукте могут быть неполными, устаревшими или покрывать только часть signal space |
| `product-owner` | Понять, какие интернет-источники покрывают ключевые сущности и насколько им можно доверять | Нет единой рамки приоритетов источников, качества и coverage |
| `system-operator` | Запускать и контролировать обновление данных без ручного разруливания по каждому источнику | Сбор из разных типов источников не оформлен как единая capability с понятными правилами |

## Goals

- `G-01` Продукт получает единый capability-layer для сбора и нормализации структурированных интернет-данных, необходимых для CS2-аналитики.
- `G-02` Capability-layer строится на документированном API-baseline; scraping или HTML-based access допустимы только как controlled optional enrichment и не образуют critical path baseline-ingestion.
- `G-03` Для обязательных canonical attributes определены source-selection policy, минимальные требования к freshness, provenance и правила разрешения конфликтов между источниками с учётом различия между `canonical baseline` и `optional enrichment`.
- `G-04` Downstream features аналитики и прогнозирования получают предсказуемую и расширяемую базу данных, где явно разделены guaranteed baseline, conditional enrichments и запрещённые или неподтверждённые source-paths.

## Non-Goals

- `NG-01` Этот PRD не описывает саму аналитику, прогнозную модель, чат-интерфейс или UX для конечного пользователя.
- `NG-02` Этот PRD не фиксирует конкретную архитектуру классов, очередей, таблиц или схемы orchestration.
- `NG-03` Инициатива не обязана сохранять текущий код сбора данных, если downstream design показывает, что reuse ухудшает целостность capability.
- `NG-04` Инициатива не требует покрыть все возможные внешние источники; нужен управляемый и расширяемый baseline.
- `NG-05` Ручной research источников без последующей продуктовой формализации не считается завершением инициативы.

## Product Scope

Инициатива покрывает capability-level слой, который умеет получать интернет-данные из разных источников, приводить их к каноничным сущностям проекта и делать этот слой пригодным для дальнейшей аналитики.

### In Scope

- Определение набора поддерживаемых source modes: документированный API-baseline и ограниченный enrichment-доступ к HTML/navigation sources.
- Определение guaranteed baseline-категорий: `matches/schedule`, `teams`, `players`, `tournaments/bracket context`, `tournament rosters`, а также справочный `league` / `serie` / `map` context там, где он подтверждён baseline API.
- Поддержка canonical identity layer и source-to-canonical mapping минимум для `team`, `player` и `tournament`.
- Фиксация source-selection policy для обязательных canonical attributes вместо грубого category-level priority.
- Фиксация правил freshness, completeness и conflict resolution на уровне capability.
- Controlled optional enrichment для `HLTV ranking`, `membership history / transfers`, `current roster snapshots` и `veto / map tendency`, если эти данные собираются узким allowlist-подходом, с кешированием и без превращения `HLTV` в baseline dependency.
- Возможность повторяемого запуска сбора данных по источнику и по категории сущностей.
- Подготовка downstream-слоя для feature packages аналитики, прогноза и пользовательских ответов.

### Out Of Scope

- Формирование betting recommendations и probabilistic model output.
- Пользовательский чат, UI-ленты и объяснение прогнозов.
- Авторизация, персонализация и пользовательская история.
- Полная автоматизация всех cron/scheduling сценариев, если она не нужна для завершения baseline capability.
- Обязательная совместимость с текущими точечными интеграциями, импортёрами и историческими решениями.
- `news` и другие неструктурированные новостные сущности как отдельная acquisition-area baseline scope.
- Отдельная первичная `transfer`-сущность или самостоятельный transfer-stream; для baseline scope достаточно membership history, из которой можно восстановить изменения состава.
- Scraping-first стратегия, широкий historical mirror сторонних сайтов или high-volume crawling без документированного API-контракта.
- Любой acquisition flow, требующий anti-bot bypass, stealth browser, proxy rotation, captcha solving или иной обход ограничений источника.

## UX / Business Rules

- `BR-01` Для обязательных canonical attributes должна быть определена source-selection policy, включая authoritative source и допустимую fallback-стратегию, если основной источник недоступен или недостаточен.
- `BR-02` Продукт не должен считать существующую реализацию сбора данных канонической рамкой для этой инициативы; reuse или redesign определяются downstream design.
- `BR-03` Baseline-ingestion должен опираться на документированные и воспроизводимые source contracts; наблюдаемые, но не подтверждённые документацией поля не считаются обязательной частью baseline.
- `BR-04` Сбор из интернета должен уважать внешние ограничения источников доступа: rate limits, robots/rules доступа и anti-bot ограничения.
- `BR-05` Для каждой записи должно быть возможно определить provenance: из какого источника и каким способом она получена.
- `BR-06` Конфликтующие данные из разных источников не должны молча смешиваться без зафиксированного приоритета или явного правила разрешения.
- `BR-07` `HLTV` и аналогичные HTML/navigation sources допустимы только как `optional enrichment`, не могут быть `primary source` для baseline-сущностей и не должны переопределять canonical значения из официальных или документированных API-источников.
- `BR-08` Для enrichment-доступа к `HLTV` и аналогичным источникам обязателен узкий allowlist страниц, агрессивное кеширование, низкая частота запросов и hard stop при `403`, `429`, CAPTCHA/challenge или ином признаке bot protection.
- `BR-09` Частично успешный сбор допустим, если система умеет явно отделять `complete`, `partial` и `failed` result по источнику или категории. Операционные semantics, обязательные attribute sets и thresholds для этих статусов формализуются отдельным ADR.
- `BR-10` Инициатива должна завершиться не только research-результатом, но и работающей реализацией capability хотя бы для минимально достаточного baseline-набора категорий данных.
- `BR-11` Baseline capability обязана поддерживать canonical identity layer и source-to-canonical mapping минимум для `team`, `player` и `tournament`; реализация, в которой baseline-ingestion работает без этого слоя, не считается достаточной.
- `BR-12` Данные, доступные только на платных или live/historical планах внешнего API, а также поля без проверяемого документированного подтверждения, не входят в baseline-контракт.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Успешность baseline-ingestion runs без ручного вмешательства | Не определено | >= 90% на baseline-сценариях | Логи capability runs за согласованное окно наблюдения |
| `MET-02` | Доля canonical records baseline-сущностей, имеющих source-to-canonical identity mapping | 0% | 100% для `team`, `player`, `tournament` в рамках baseline coverage | Проверка capability verify и data quality reports |
| `MET-03` | Доля обязательных canonical attributes, для которых определены source-selection policy и provenance | 0% | 100% для baseline mandatory attribute set | Ревью capability rules и verify-артефактов |
| `MET-04` | Доля baseline-records, классифицированных как `complete` или допустимо `partial` по утверждённым thresholds | Не определено | >= 95% classified, из них unresolved conflict rate <= 5% | Data quality reports по capability runs |
| `MET-05` | Freshness baseline-данных по семействам сущностей в пределах утверждённых SLA/thresholds | Не определено | 100% для обязательных entity families в agreed thresholds | Сверка `fetched_at`/effective timestamps с capability policy |

## Risks And Open Questions

- `RISK-01` Даже optional enrichment-источники могут оказаться нестабильными или недопустимыми из-за anti-bot защиты, rate limits и юридических ограничений.
- `RISK-02` Разные источники могут давать несовместимые идентификаторы, таймзоны, naming conventions, разные semantics дат membership и разную степень детализации.
- `RISK-03` Попытка включить в baseline неподтверждённые или paid-only API поля размоет контракт и приведёт к ложным продуктовым обещаниям.
- `RISK-04` Попытка покрыть слишком много enrichment-сценариев сразу может размыть baseline scope и затормозить доставку capability.
- `OQ-01` Какие optional enrichment slices действительно нужны в первом продуктовом контуре после baseline: `HLTV ranking`, `membership history`, `veto/map tendency` или только их часть?
- `OQ-02` Какой уровень near-real-time freshness действительно нужен для разных категорий данных: матчи, ростеры, rankings и связанные structured entities?
- `OQ-03` Понадобится ли отдельное решение по paid historical/live data, или baseline free/API scope достаточен для целевой аналитики первого релиза?

## Downstream Features

| Feature | Why it exists | Status |
| --- | --- | --- |
| `FT-003` | Каталог интернет-источников и capability-правила: baseline-vs-enrichment classification, source-selection policy, freshness, provenance | planned |
| `FT-004` | Ingestion pipeline для documentable API-baseline по `matches/schedule`, `teams`, `players`, `tournaments` и `tournament rosters` | planned |
| `FT-005` | Controlled enrichment pipeline для узких HTML/navigation sources без scraping-first зависимости baseline | planned |
| `FT-006` | Нормализация, conflict resolution и identity mapping между canonical baseline и optional enrichment-источниками | planned |
| `FT-007` | Операционный контур запуска, контроля качества и повторных обновлений данных | planned |
