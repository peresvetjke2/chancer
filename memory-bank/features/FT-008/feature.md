---
title: "FT-008: Baseline Coverage PandaScore по сущностям, атрибутам и freshness expectations"
doc_kind: feature
doc_function: canonical
purpose: "Canonical feature-документ для фиксации baseline PandaScore coverage contract: какие сущности и атрибуты считаются обязательными на первом этапе и какие ожидания по freshness должны сопровождать downstream ingestion."
derived_from:
  - ../../domain/problem.md
  - ../../domain/cs2-data-attributes.md
  - ../../prd/PRD-002-pandascore-data-acquisition.md
status: draft
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-008: Baseline Coverage PandaScore по сущностям, атрибутам и freshness expectations

## What

### Problem

`PRD-002` уже требует зафиксировать baseline scope PandaScore, но пока не существует feature-level артефакта, который переводит это требование в конкретный delivery slice. Из-за этого непонятно, какие именно CS2-сущности входят в baseline первого этапа, какие атрибуты по каждой сущности считаются mandatory или допустимо partial, и какие freshness thresholds downstream-импорт должен затем соблюдать.

Без такого документа последующие фичи ingest-а (`FT-009`, `FT-010`, `FT-011`) будут вынуждены принимать product decisions по coverage ad hoc: по наличию поля в API, по текущему коду импортера или по локальным предположениям, а не по согласованному контракту.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Доля baseline PandaScore entities первого этапа, явно перечисленных в feature-артефакте | 0% | 100% | Ревью canonical doc |
| `MET-02` | Доля baseline attributes, классифицированных как `mandatory`, `optional`, `derived` или `gap` | 0% | 100% для agreed baseline scope | Ревью coverage matrix |
| `MET-03` | Доля agreed freshness expectations, явно закрепленных по типам данных или жизненным состояниям | 0% | 100% для baseline scope | Ревью freshness section |

### Scope

- `REQ-01` Создать canonical baseline coverage doc для PandaScore CS2 scope первого этапа с явным перечислением baseline-сущностей.
- `REQ-02` Для каждой baseline-сущности зафиксировать attribute-level coverage contract: какие поля обязательны для downstream use, какие допустимы как optional, какие являются derived, а какие остаются gap.
- `REQ-03` Зафиксировать freshness expectations для baseline-сущностей или их жизненных состояний так, чтобы downstream ingestion-фичи могли опираться на них как на product input.
- `REQ-04` Явно обозначить open questions и известные gaps PandaScore coverage, которые нельзя молча интерпретировать как поддерживаемые данные.

### Non-Scope

- `NS-01` Фича не реализует сам ingestion, upsert, scheduling или verify-код в приложении.
- `NS-02` Фича не обещает покрытие всех PandaScore-сущностей за пределами baseline первого этапа.
- `NS-03` Фича не валидирует live API PandaScore в рантайме и не заменяет собой техническое исследование фактической доступности каждого поля.
- `NS-04` Фича не меняет схему БД, модели Rails и существующие импортёры.

### Constraints / Assumptions

- `ASM-01` Upstream owner этой фичи — [PRD-002](../../prd/PRD-002-pandascore-data-acquisition.md), и baseline должен быть согласован с его целями `G-02` и `G-03`.
- `ASM-02` Для первого этапа baseline определяется вокруг сущностей, нужных downstream ingestion-фичам для матчей, команд и игроков, а расширение на вторичные сущности допускается только при явной пользе для этих flows.
- `CON-01` Документ должен различать `mandatory`, `optional`, `derived` и `gap`, чтобы downstream-фичи не трактовали отсутствие данных как неявно допустимое состояние.
- `CON-02` Freshness expectations должны быть выражены в форме, пригодной для последующего verify-контракта, а не как общее пожелание "обновлять регулярно".
- `DEC-01` Ещё не принято решение, входят ли в baseline первого этапа `tournament`, `serie`, `league` и roster-level данные как обязательные сущности или только как supporting context.

## How

### Solution

Фича создаёт canonical documentation slice в feature package `FT-008`: документ должен собрать baseline PandaScore contract в одном месте и разложить его по трём осям `entity coverage`, `attribute coverage`, `freshness expectations`. Главный trade-off: сначала фиксируем продуктовый минимум и явные gaps, а не пытаемся документировать весь PandaScore API.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `memory-bank/features/FT-008/feature.md` | doc | Canonical owner intent, scope, design и verify для baseline coverage slice |
| `memory-bank/features/FT-008/README.md` | doc | Routing layer для нового feature package |
| `memory-bank/features/README.md` | doc | Регистрация новой instantiated feature в общем индексе |

### Flow

1. Upstream PRD задаёт требование определить baseline coverage PandaScore.
2. `FT-008` фиксирует, какие сущности и атрибуты считаются продуктово обязательными на первом этапе, и какие freshness expectations с ними связаны.
3. Downstream ingest и verify features используют этот документ как canonical input для реализации и проверок.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | Baseline entity inventory | `FT-008` → `FT-009`, `FT-010`, `FT-011` | Минимальный согласованный перечень сущностей PandaScore первого этапа |
| `CTR-02` | Attribute coverage matrix (`mandatory` / `optional` / `derived` / `gap`) | `FT-008` → downstream ingestion/verify work | Нельзя подменять отсутствующее решение имплицитной трактовкой поля |
| `CTR-03` | Freshness expectations по baseline scope | `FT-008` → future verify contracts | Должны быть переведены в проверяемые thresholds или rules |

### Failure Modes

- `FM-01` Документ перечислит сущности без attribute-level классификации, и downstream-команды снова будут додумывать обязательность полей локально.
- `FM-02` Freshness expectations останутся расплывчатыми, из-за чего `FT-011` не сможет построить верифицируемые stale-check rules.
- `FM-03` Вторичные PandaScore-сущности будут включены в baseline без явного product-обоснования, что размоет scope и задержит реализацию ingest критичного минимума.

## Verify

### Exit Criteria

- `EC-01` В feature package существует canonical doc, который явно перечисляет baseline PandaScore entities первого этапа.
- `EC-02` Для каждой baseline-сущности в документе задана attribute-level классификация, достаточная для downstream-решений без скрытых предположений.
- `EC-03` Документ фиксирует freshness expectations в форме, пригодной для последующего verify и stale-detection contract.
- `EC-04` Известные gaps и unresolved decisions перечислены явно и не замаскированы как уже поддерживаемое покрытие.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-01`, `ASM-02`, `CTR-01`, `FM-03` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-01`, `CTR-02`, `FM-01` | `EC-02`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `CON-02`, `CTR-03`, `FM-02` | `EC-03`, `SC-02` | `CHK-01` | `EVID-01` |
| `REQ-04` | `DEC-01`, `FM-01`, `FM-03` | `EC-04`, `SC-03` | `CHK-01` | `EVID-01` |

### Acceptance Scenarios

- `SC-01` Product owner или downstream feature owner открывает `FT-008` и без обращения к коду понимает, какие PandaScore-сущности и атрибуты входят в baseline первого этапа и какие из них обязательны.
- `SC-02` Owner `FT-011` открывает `FT-008` и может вывести из документа проверяемые freshness rules для active, upcoming или reference-like данных без догадок о допустимой устарелости.
- `SC-03` Если по части сущностей или полей нет подтверждённого решения, документ явно помечает их как `gap` или open question, а не включает в baseline молча.

### Checks

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-02`, `EC-03`, `EC-04`, `SC-01`, `SC-02`, `SC-03` | Manual review of `memory-bank/features/FT-008/feature.md` against `PRD-002` and downstream dependencies | В документе явно присутствуют entity inventory, attribute coverage rules, freshness expectations и gap/open-question inventory | `artifacts/ft-008/verify/chk-01/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-008/verify/chk-01/` |

### Evidence

- `EVID-01` Ссылка на ревью или сохранённый verify note, подтверждающий, что canonical doc покрывает entity scope, attribute matrix, freshness expectations и явные gaps.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Review note / approved doc review output | verify-runner / human | `artifacts/ft-008/verify/chk-01/` | `CHK-01` |
