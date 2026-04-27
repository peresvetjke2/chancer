---
title: "ADR-004: HLTV Enrichment And Controlled Acquisition Strategy"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует, какие CS2-атрибуты HLTV потенциально может обогащать сверх PandaScore baseline, а также policy и эксплуатационную стратегию для работы с HLTV."
derived_from:
  - ../domain/cs2-data-attributes.md
  - ./ADR-003-pandascore-free-api-attribute-scope.md
status: draft
decision_status: approved
date: 2026-04-27
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-004: HLTV Enrichment And Controlled Acquisition Strategy

## Контекст

`ADR-003` зафиксировал узкий, доказуемый baseline structured-data contract на базе `PandaScore free API`. Этот baseline полезен, но не покрывает значительную часть canonical-атрибутов из `memory-bank/domain/cs2-data-attributes.md`.

`HLTV` выглядит естественным кандидатом на enrichment, потому что публично показывает несколько категорий данных, которых нет в baseline `PandaScore`: собственный ranking, roster timeline, transfer feed, team-centric veto/map tendencies и более богатый navigation context вокруг команд и матчей.

Одновременно `HLTV` принципиально отличается от `PandaScore` по способу доступа. В ходе повторной проверки публичных материалов на `2026-04-27` подтверждается следующее:

- у `HLTV` нет подтвержденного публичного официального API для такого использования; в публичном поле распространены только неофициальные wrappers;
- `HLTV Terms of Service` прямо запрещают `commercially exploit`, `data mining` и `web scraping`;
- публичные страницы `HLTV` действительно содержат ценные CS2-сигналы, но они представлены как HTML/navigation surface, а не как стабильный документированный data contract;
- maintainers популярного неофициального wrapper-а отдельно предупреждают о риске `IP ban` из-за bot protection, что усиливает операционный риск машинного доступа.

Поэтому нужен ADR не про "можно ли парсить HLTV вообще", а про гораздо более узкий вопрос: какие `entity families` и `attribute IDs` HLTV теоретически способен обогатить сверх `PandaScore`, и при каких условиях такой доступ остается строго optional, controlled и не входит в baseline-контракт.

## Драйверы решения

- Базовые доменные атрибуты будут загружаться из PandaScore (см. "2.1. Связь с `memory-bank/domain/cs2-data-attributes.md`" в `ADR-003`)
- `HLTV` должен рассматриваться только как non-baseline enrichment candidate, а не как замена документированному API.
- Нужна явная граница между "publicly visible on HLTV" и "допустимо включать в системный acquisition flow".
- Нужна attribute-level фиксация, какие доменные поля HLTV покрывает лучше всего, какие покрывает частично, а какие не должен обещать.
- Нужны stop-conditions, чтобы downstream-реализация не скатилась в scraping-first стратегию или в обход anti-bot защиты.
- Юридическая и коммерческая договоренность с `HLTV`, если она когда-либо понадобится, вне рамок этого исследования; ADR фиксирует только техническую и policy-сторону публичного доступа.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему рассматривается как основной кандидат / не основной кандидат |
| --- | --- | --- | --- |
| `Не использовать HLTV вообще` | нулевой legal/operational risk, самая простая политика | остаются незакрытыми `HLTV ranking`, часть `veto`, roster timeline и transfer context | не основной кандидат, потому что проекту полезно хотя бы формально зафиксировать enrichment potential и границы допустимости |
| `Использовать HLTV как второй canonical source` | максимальный coverage поверх PandaScore | противоречит ToS/operability reality, нет стабильного API-контракта, высокий anti-bot риск | не основной кандидат |
| `Использовать HLTV только вручную как research aid` | почти нет машинных рисков, можно проверять гипотезы руками | не решает вопрос системного enrichment даже для узких одноразовых snapshot-ов | полезный fallback, но слишком узко как основное решение |
| `Использовать HLTV как controlled non-canonical enrichment` | позволяет зафиксировать полезные attribute families, сохраняя HLTV вне critical path и вне baseline promises | требует строгой policy, provenance и stop-conditions; часть потенциальных данных останется intentionally unused | основной кандидат |

## Решение

Для `decision_status: proposed` предлагается считать `HLTV` допустимым только как `controlled non-canonical enrichment source`.

Это означает:

- `HLTV` не является `primary source` ни для одной baseline-сущности из `ADR-003`;
- `HLTV` не должен переопределять canonical значения, уже взятые из `PandaScore` или других официальных источников;
- любые данные из `HLTV` сохраняются только как `source-scoped snapshot` с явным provenance;
- отсутствие доступа к `HLTV` не должно ломать baseline ingestion и не должно блокировать phase-1 launch.

### 1. Что именно HLTV потенциально покрывает сверх PandaScore

| Domain area | Attribute IDs | Потенциал HLTV | Комментарий |
| --- | --- | --- | --- |
| `HLTV ranking snapshots` | `TRS-01`, `TRS-02`, `TRS-03`, `TRS-04`, `TRS-05` | высокий | это strongest-fit категория: HLTV публично ведет собственный weekly ranking с dated snapshots и points |
| `Veto / map preference context` | `VTO-01`, `VTO-02`, `VTO-03`, `VTO-04`, `VTO-05` | средний | лучше покрывается как team-level/map-level veto tendency и match-context enrichment, чем как guaranteed per-match canonical event log |
| `Membership / roster history` | `MEM-01`, `MEM-02`, `MEM-05`, `MEM-06`; частично `MEM-03`, `MEM-04` | средний | roster timeline и transfers хорошо видны на team pages, но contract слабее, чем у ranking; точные effective periods могут требовать интерпретации |
| `Current roster snapshot` | `ROS-01`; частично `ROS-02` | средний | можно собирать как производный snapshot из lineup/timeline/transfers, но не как uncontested truth |
| `Team and player profile context` | `TEM-01`, `PLY-01`, частично `PLY-02`, `PLY-04` | низкий/вспомогательный | страницы содержат богатый контекст, но это не та зона, где нужен HLTV поверх PandaScore baseline |
| `Tournament / match narrative context` | часть `MCH-*`, часть `TRN-*` | низкий/вспомогательный | полезно для manual sanity check и ad hoc research, но не как canonical acquisition contract |

### 2. Что считать рекомендуемым HLTV enrichment scope

#### 2.1. Strong candidate: `HLTV ranking`

`HLTV ranking` предлагается считать главным и наименее спорным use-case для `HLTV`, потому что:

- ranking является first-party артефактом самого `HLTV`, а не побочным извлечением из матчевых страниц;
- ranking публикуется как датированные weekly snapshots;
- страница ranking явно описывает модель обновления и расчета;
- `TRS-03 = hltv` уже предусмотрен доменной моделью.

Для ranking допустимо рассматривать `HLTV` как source-of-truth именно для `hltv`-рейтинговой системы и только для нее.

#### 2.2. Conditional candidate: `veto` и map-pool tendency

`HLTV` показывает выраженный `veto`-контекст на stats/team pages и team overview pages. Но этот сигнал предлагается трактовать узко:

- как enrichment для map-pool и veto tendency анализа;
- как best-effort source для downstream аналитики;
- не как baseline-обязательство полного и безошибочного per-match veto event log.

Иными словами, `HLTV` полезен для ответов вида "какие карты команда обычно банит/пикает" существенно больше, чем для обещания полного canonical-реестра `VTO-*` по каждому матчу.

#### 2.3. Conditional candidate: `membership history` и transfers

`HLTV` team pages и transfer pages делают возможным обогащение по roster timeline:

- кто входил в состав;
- кто покинул или присоединился к команде;
- какой event type у transfer/change;
- когда был зафиксирован переход или уход.

Но по этой зоне предлагается удержать консервативную позицию:

- `MEM-03` и `MEM-04` трактовать как `best-effort source-reported dates`, а не как юридически или контрактно точные даты действия membership;
- `MEM-05` и `MEM-06` допускать только если роль/статус реально выражены на странице, а не выведены эвристикой;
- `ROS-*` считать derived representation поверх membership/transfer snapshots, а не raw truth из `HLTV`.

#### 2.4. Explicit non-candidate: baseline structured acquisition

Следующие зоны предлагается не считать целевым `HLTV enrichment scope` для phase 1:

- canonical расписание матчей;
- canonical результаты матчей;
- canonical турниры и tournament roster baseline;
- round-by-round history как обещанный системный контракт;
- любой high-volume crawling ради полного исторического зеркала `HLTV`.

### 3. Acquisition policy для любого машинного доступа к HLTV

Любой машинный доступ к `HLTV` предлагается считать допустимым только при одновременном выполнении всех условий ниже:

1. Доступ нужен для `optional enrichment`, а не для baseline ingestion.
2. Данные нельзя получить сопоставимо надежно из уже разрешенного API-источника.
3. Сбор ограничен узким allowlist-ом страниц или page families, а не broad crawl-ом.
4. Частота доступа низкая, результаты aggressively cache-ируются, повторный сбор без необходимости не выполняется.
5. Не используется login, captcha solving, stealth browser, proxy rotation, anti-bot bypass или иная техника обхода ограничений сайта.
6. При первом признаке блокировки или нестабильности enrichment выключается, а не "лечится" усложнением scraping stack.
7. Сохраненные данные маркируются как `HLTV-derived` и не смешиваются с canonical baseline без source-priority rules.

### 4. Stop-conditions

Ниже предлагается считать hard stop для автоматизированной работы с `HLTV`:

- появляется CAPTCHA, challenge page, `403`, `429` или иная явная bot-protection реакция;
- для поддержания данных в актуальном состоянии требуется регулярный высокочастотный scraping;
- downstream feature начинает зависеть от `HLTV` как от обязательного источника для core product flow;
- HTML/navigation меняется так, что extraction становится хрупким и требует постоянного ad hoc сопровождения;
- нужный атрибут можно получить из разрешенного API-источника, а `HLTV` остается только "потому что там удобнее";
- для достижения цели требуется обход ToS-ограничений или усложнение сетевой инфраструктуры;
- юридическая или коммерческая оценка later-stage rollout покажет, что такой use-case нельзя согласовать с intended business use.

### 5. Operational interpretation

- `HLTV` допускается как `optional enrichment layer`, но не как foundation.
- Если enrichment из `HLTV` недоступен, система деградирует в `PandaScore-only` режим без функциональной аварии baseline.
- Внутри source catalog `HLTV` должен иметь более низкий trust/operability priority, чем документированные API-источники.
- Для ranking допустим больший уровень уверенности, чем для transfers/veto timeline, потому что ranking у `HLTV` является first-party curated output.
- Для `MEM-*` и `VTO-*` downstream-документы должны явно писать `best effort` или `conditional`, если эти атрибуты зависят от `HLTV`.

## Последствия

### Положительные

- Появляется формальная граница между полезностью `HLTV` и недопустимостью scraping-first стратегии.
- `TRS-*` для `hltv` получает естественный upstream-кандидат без размывания baseline-контракта `ADR-003`.
- `VTO-*` и `MEM-*` можно исследовать как отдельные enrichment slices без обещания production-grade гарантии на старте.
- Downstream-решения получают готовые stop-conditions и не должны самостоятельно изобретать policy для anti-bot сценариев.

### Отрицательные

- Значительная часть видимых на `HLTV` данных сознательно останется вне гарантированного acquisition scope.
- Для некоторых интересных сигналов, особенно по `veto` и roster timeline, придется жить с `best effort` semantics вместо строгого canonical contract.
- Документ вводит дополнительную operational дисциплину: provenance, caching, controlled acquisition и explicit degradation behavior.

### Нейтральные / организационные

- Если команда когда-либо захочет production-scale использование `HLTV`, потребуется отдельный ADR с legal/commercial reassessment.
- Feature-документы, которые используют `HLTV`, должны явно ссылаться на этот ADR и маркировать свои зависимости как optional или conditional.
- Source catalog и verify contract должны различать `canonical`, `optional enrichment`, `manual research only` и `forbidden automated access`.

## Риски и mitigation

- Риск: разработка начнет воспринимать "данные видны на сайте" как разрешение на системный scraping.
  Mitigation: считать этот ADR закрывающим policy-вопрос; без отдельного последующего ADR `HLTV` не может стать baseline source.
- Риск: `HLTV ranking` смешается с `Valve VRS` или иными ranking systems.
  Mitigation: хранить `TRS-03` как явный enum рейтинговой системы и не смешивать snapshots разных провайдеров.
- Риск: transfers/timeline дадут ложное ощущение точности по датам membership.
  Mitigation: даты из `HLTV` в этой зоне трактовать как source-reported event dates, а не как гарантированно точные contract periods.
- Риск: попытка стабилизировать `HLTV` приведет к усложнению scraping-инфраструктуры.
  Mitigation: hard stop на proxy rotation, challenge bypass и иной anti-bot evasion.
- Риск: downstream аналитика будет строиться на `veto` как будто это полный per-match event log.
  Mitigation: в downstream docs явно ограничивать use-case как team/map tendency enrichment, если не доказана стабильная event-level полнота.

## Follow-up

- Завести source catalog entry для `HLTV` с колонками `allowed_scope`, `forbidden_scope`, `access_mode`, `trust_level`, `stop_conditions`.
- Если ranking snapshots действительно нужны продукту, оформить отдельный downstream doc по `HLTV ranking ingestion`, не смешивая его с `veto` и `transfers`.
- Если проект вернется к roster-history enrichment, отдельно описать mapping from `HLTV transfers/timeline` to `MEM-*` semantics.
- В verify contract добавить классы `hltv-strong`, `hltv-conditional`, `hltv-manual-only`.

## Связанные ссылки

- [CS2 Data Attributes](../domain/cs2-data-attributes.md)
- [ADR-003: PandaScore Free API Attribute Scope](./ADR-003-pandascore-free-api-attribute-scope.md)
- [Project Problem Statement](../domain/problem.md)
- [Architecture Patterns](../domain/architecture.md)
- [HLTV Terms of Service](https://www.hltv.org/terms)
- [HLTV Team Ranking](https://www.hltv.org/ranking/teams)
- [HLTV historical ranking snapshot example](https://www.hltv.org/ranking/teams/2026/february/9/12834)
- [HLTV transfers page](https://www.hltv.org/transfers)
- [HLTV team page example with roster timeline](https://www.hltv.org/team/7667/ranks)
- [HLTV team overview example with current ranking and map/veto context](https://www.hltv.org/team/7175/team)
- [HLTV team veto stats example](https://www.hltv.org/stats/teams/10717/veto)
- [Unofficial HLTV Node.js API repository](https://github.com/gigobyte/HLTV)
