---
title: CS2 Data Sources
doc_kind: domain
doc_function: supporting
purpose: Research-описание возможных интернет-источников для загрузки структурированных CS2-данных. Читать как supporting input к ADR и к проектированию ingestion-layer.
derived_from:
  - cs2-data-attributes.md
  - ../prd/PRD-001-internet-data-acquisition.md
  - problem.md
status: active
audience: humans_and_agents
---

# CS2 Data Sources

Этот документ фиксирует исследование возможных источников для загрузки данных, описанных в [CS2 Data Attributes](cs2-data-attributes.md). Его задача не в том, чтобы перечислить все существующие сайты про CS2, а в том, чтобы зафиксировать практичный baseline: какие источники реально покрывают нужные атрибуты, каким способом к ним можно подключаться, какие у них ограничения и какую роль они должны играть в ingestion-layer.

Оценка ниже актуальна на `2026-04-24`.

## Decision Summary

- `PandaScore API` — лучший baseline-источник для матчей, расписания, турниров, базовых команд/игроков и части roster/statistics-данных. Это единственный явно document-driven API, уже частично встроенный в проект.
- `HLTV` — лучший источник CS-специфичных ranking / veto / roster-history / match-context данных, но только как controlled scraping fallback или enrichment, а не как foundation, из-за anti-bot и отсутствия официального публичного API.
- `Liquipedia API / LiquipediaDB / MediaWiki API` — сильный источник для roster-history, трансферов, турнирного контекста и справочной историчности. Хорош как secondary source и identity-resolution aid, но требует строгого соблюдения их API terms.
- `Valve Regional Standings / rules repositories` — canonical-источник для модели VRS и tournament-invite semantics, но не для полной базы матчей. Нужен как отдельный source family для рейтинговой системы `valve_regional_standings`.
- `BO3.gg` и похожие агрегаторы можно держать только как exploratory / last-resort candidates. На текущем этапе они не выглядят лучше пары `PandaScore + HLTV + Liquipedia + Valve`.

## Evaluation Criteria

При оценке источников использовались четыре критерия:

- `coverage` — насколько источник закрывает атрибуты из `cs2-data-attributes.md`.
- `access model` — официальный API, semi-official API, scraping, публичный dataset или иная форма доступа.
- `operability` — rate limits, anti-bot, стабильность схемы, пригодность для повторяемого ingestion.
- `trust / provenance` — насколько понятно, откуда берутся данные, и можно ли ссылаться на источник как на source-of-truth.

## Source Matrix

| Источник | Тип доступа | Сильные стороны | Главные ограничения | Рекомендуемая роль |
| --- | --- | --- | --- | --- |
| `PandaScore` | официальный REST API, платные уровни для historical/live | матчи, расписание, турниры, команды, игроки, пост-матч статистика | round-level data и часть detailed stats зависят от плана; coverage не одинаковая по турнирам | `primary` для baseline ingestion |
| `HLTV` | HTML scraping, неофициальные wrapper-ы | мировые рейтинги, rich CS context, roster timeline, veto-related context, match pages | anti-bot / Cloudflare, нет официального публичного API, высокий ops-risk | `secondary` / `fallback` / `enrichment` |
| `Liquipedia` | LiquipediaDB API, MediaWiki API, запрещён HTML scraping | ростеры, трансферы, турнирная история, справочные связи, VRS-производные страницы | rate limits, licensing / attribution, коммерческий доступ через approval | `secondary` для roster-history и identity support |
| `Valve` | официальные GitHub repositories / published standings data | canonical semantics для VRS, regional assignment, invite rules | не покрывает общую матчевую историю и roster DB как продуктовый API | `primary` для `ranking_system = valve_regional_standings` |
| `BO3.gg` | фактически сайт; публично документированного API не найдено | широкий CS2 coverage, live-oriented presentation, round-level depth по сайту | неясный статус API и licensing, слабый contractual certainty | только `research_candidate` |

## Attribute Coverage

### Матчи и карты

`PandaScore` хорошо покрывает:

- `MCH-01` запланированное время
- `MCH-02` формат серии
- `MCH-03` статус
- `MCH-04` участников
- `MCH-05` турнир
- `MCH-06` и частично `MCH-07` турнирный контекст
- `MCH-09` source-reported счёт серии
- `MAP-01` ... `MAP-05` на уровне games/maps

`PandaScore` хуже подходит или требует платного плана для:

- `MAP-07` история раундов
- match/player/team detailed stats
- near-real-time low-latency ingestion

`HLTV` дополняет `PandaScore` по:

- richer match page context
- map veto context
- lineup / ranking context вокруг матча
- историческим team pages и stats pages

`Liquipedia` полезна как fallback для:

- tournament stage / round labels
- schedule sanity checks
- historical match/tournament context

### Veto

Из исследованных источников именно `HLTV` выглядит самым практичным кандидатом на `VTO-*` данные, потому что CS-specific match pages и team veto stats содержат информацию, близкую к нужной модели pick/ban flow.

`PandaScore` в открытой документации не выглядит как надёжный canonical-источник для полного последовательного veto-log. Поэтому veto лучше сразу проектировать как optional enrichment path, а не как baseline ingestion requirement первого шага.

### Турниры

`PandaScore` даёт сильный baseline по турнирам, участникам и bracket-oriented структуре.

`Liquipedia` лучше подходит для:

- исторической полноты
- турнирных уровней / категорий
- roster snapshots и transfer-adjacent context
- восстановления неформализованных stage labels, если primary source слишком грубый

### Команды, рейтинги и ростеры

`HLTV` силён для:

- `TRS-03 = hltv`
- текущего world ranking
- roster timeline
- текущего core lineup

`Valve` обязателен для:

- `TRS-03 = valve_regional_standings`
- official invite semantics
- regional assignment logic для major ecosystem

`Liquipedia` силён для:

- membership history
- inactive / former / loan / coach / stand-in контекста
- transfer-related evidence

`PandaScore` полезен для:

- baseline team/player entities
- tournament rosters
- player-to-team history через tournament participation

Но `PandaScore` сам рекомендует использовать именно tournament rosters, а не team-level contracted players, если цель — определить реальных участников турнира.

### Игроки

`PandaScore` покрывает базовые player entities и статистику.

`Liquipedia` лучше подходит для историчности membership и role/status-like контекста.

`HLTV` полезен для player pages, рейтингового и performance-контекста, но менее безопасен как системный foundation из-за scraping-only доступа.

## Recommended Source Priority

### Baseline первого этапа

| Категория | Primary | Secondary / Fallback | Комментарий |
| --- | --- | --- | --- |
| Матчи и schedule | `PandaScore` | `Liquipedia`, `HLTV` | Надёжнее всего стартовать с API |
| Турниры и bracket context | `PandaScore` | `Liquipedia` | `PandaScore` даёт структурированный baseline |
| Команды и игроки | `PandaScore` | `Liquipedia`, `HLTV` | Для canonical entity bootstrap |
| Tournament rosters | `PandaScore` | `Liquipedia` | Не путать с contracted players |
| HLTV world ranking | `HLTV` | none | Отдельная ranking system, хранить как source-specific snapshot |
| Valve Regional Standings | `Valve` | `Liquipedia` only for sanity check | Источник истины именно `Valve` |
| Membership history / transfers | `Liquipedia` | `HLTV`, news sources later | Для membership timeline пока выглядит сильнее |
| Veto | `HLTV` | none | Optional enrichment, не baseline-blocker |
| Round history | `PandaScore` paid tiers | `BO3.gg` research only | Не обещать в baseline без валидации тарифа и coverage |

## Source Notes

### PandaScore

Почему это основной кандидат:

- Документация прямо описывает three-tier coverage: `fixtures`, `historical`, `live`.
- Для CS2 используется тот же `/csgo/` namespace, что снимает ambiguity при интеграции.
- Документация отдельно описывает tournament rosters и bracket semantics.
- Проект уже использует `Pandascore::Client`, значит operational learning уже есть.

Практические выводы:

- Если нужен минимально жизнеспособный ingestion-layer, он должен строиться вокруг `PandaScore`.
- Нельзя предполагать наличие детальных stats у каждого матча: ingestion должен уважать `detailed_stats` и `complete`.
- `MAP-07` round history нельзя считать baseline-атрибутом бесплатного или минимального плана: endpoint rounds доступен только real-time customers.

### HLTV

Почему источник ценен:

- Даёт те CS-специфичные сущности, которых часто не хватает общим esports API: rich rankings, roster timeline, veto context, deep stats pages.
- Командные страницы содержат world ranking и roster timeline, что близко к `TRS-*`, `ROS-*`, `MEM-*`.

Почему источник рискованный:

- В проекте уже зафиксировано, что HLTV scraping находится на паузе из-за anti-bot защиты.
- Сообщество wrapper-ов вокруг HLTV прямо предупреждает о риске IP bans и нестабильности.
- Отсутствует официальный публичный API с контрактом схемы.

Практические выводы:

- HLTV нельзя делать hard dependency для первого production-like baseline.
- HLTV стоит подключать как carefully rate-limited enrichment pipeline с явным `source_status`.
- Любые HLTV-derived данные надо хранить как source-scoped snapshots, а не как uncontested truth.

### Liquipedia

Почему источник полезен:

- Их API-позиционирование прямо обещает data types для matches, players, teams, tournaments, standings и transfers.
- Для CS ecosystem именно Liquipedia часто лучше других источников хранит roster-history и transfer-history.
- Есть formal terms of use и formal access models, что лучше обычного scraping.

Главные ограничения:

- Liquipedia прямо запрещает automated access к non-API HTML endpoints.
- Для LiquipediaDB нужен approved request и соблюдение limit `60 requests / hour`.
- Требуются caching и attribution.
- Free access явно недоступен для betting-related projects, что особенно важно для текущего продукта.

Практические выводы:

- Для `Chancer` Liquipedia выглядит полезной, но не гарантированно доступной для production use-case без отдельного согласования.
- Этот источник стоит проектировать как optional approved integration, а не как assumed baseline.
- MediaWiki/API path может быть полезен для research и частичных non-commercial сценариев, но product assumptions должны исходить из worst-case: доступ могут не дать.

### Valve

Почему источник обязателен:

- Если в модели существует `ranking_system = valve_regional_standings`, то источник истины должен быть связан с `Valve`, а не с третьим агрегатором.
- Valve публикует model/rules контекст через официальные GitHub repositories.
- Rulebook фиксирует, что VRS используется для invitation logic и regional assignment.

Ограничения:

- Это не универсальный матчевый API.
- Для повседневного ingestion матчей, игроков и карт источник бесполезен без дополнительных слоёв.

Практические выводы:

- `Valve` нужен не вместо `PandaScore`, а рядом с ним.
- Хранить VRS нужно как отдельный ranking snapshot family со своим provenance.

### BO3.gg

Почему вообще рассматривается:

- Сайт заявляет live match data, player/team statistics, transfer tracking и round-by-round coverage.
- Во внешних wrapper-ах BO3.gg позиционируется как practical alternative к HLTV.

Почему пока не стоит закладывать в core design:

- Не найдено официальной публичной API-документации с устойчивым контрактом.
- Неясны licensing, terms и operational guarantees.
- Это создаёт почти те же риски, что и HLTV, но с меньшей репутационной устойчивостью как source-of-truth.

Практический вывод:

- Оставить как резервный research candidate, но не включать в canonical priority list первого этапа.

## Recommended Ingestion Shape

Для первого этапа разумна такая модель:

1. `PandaScore` как primary API для матчей, турниров, teams, players, tournament rosters и baseline stats.
2. `Valve` как отдельный официальный источник только для VRS-related snapshots и правил интерпретации ranking system.
3. `HLTV` как selective enrichment для ranking snapshots, veto и roster timeline, когда это действительно нужно downstream-фичам.
4. `Liquipedia` как optional approved source для membership-history, transfer-like context и identity reconciliation, если юридически и операционно доступ разрешён.

## Baseline Gaps

После исследования остаются четыре явных gap-а:

- `VTO-*` не имеет такого же clean official API-candidate, как match-level данные.
- `MAP-07` round history у `PandaScore` зависит от higher-tier access и не должна silently входить в baseline promises.
- `MEM-*` и transfer reconstruction потребуют отдельной стратегии, потому что ни один baseline source не даёт идеальную membership history без компромиссов.
- `identity resolution` между `PandaScore`, `HLTV`, `Liquipedia` и `Valve` придётся проектировать отдельно; источники дают разные identifiers и разные entity boundaries.

## Canonical Source Guidance

- Не смешивать разные ranking systems в одном поле без `ranking_system`.
- Не понижать `Valve` до статуса "ещё одного рейтинга" рядом с `HLTV`: это другой класс источника и другой бизнес-смысл.
- Не трактовать team-level roster у `PandaScore` как reliable tournament participation snapshot, если есть tournament rosters.
- Не использовать HTML scraping Liquipedia, потому что их terms это запрещают.
- Не делать HLTV обязательным для успешного nightly refresh baseline-данных.

## References

- PandaScore Introduction: https://developers.pandascore.co/docs/introduction
- PandaScore FAQ: https://developers.pandascore.co/docs/frequently-asked-questions
- PandaScore Tournaments In-Depth: https://developers.pandascore.co/docs/tournaments-in-depth
- PandaScore CS rounds endpoint: https://developers.pandascore.co/reference/get_csgo_games_csgogameid_rounds-1
- Liquipedia API page: https://liquipedia.net/api
- Liquipedia API Terms: https://liquipedia.net/api-terms-of-use
- Liquipedia Counter-Strike main page: https://liquipedia.net/counterstrike/Main_Page
- HLTV team page example with ranking and roster timeline: https://www.hltv.org/team/12457/rounds
- HLTV stats pages: https://www.hltv.org/stats
- HLTV map/veto stats example: https://www.hltv.org/stats/teams/maps/10717/veto?csVersion=CS2
- Valve Regional Standings repository: https://github.com/ValveSoftware/counter-strike_regional_standings
- Valve Major Supplemental Rulebook: https://github.com/ValveSoftware/counter-strike_rules_and_regs/blob/main/major-supplemental-rulebook.md
