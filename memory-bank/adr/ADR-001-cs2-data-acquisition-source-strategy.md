---
title: "ADR-001: CS2 Data Acquisition Source Strategy"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует стратегию выбора primary и fallback источников для ingestion-layer структурированных CS2-данных."
derived_from:
  - ../prd/PRD-001-internet-data-acquisition.md
  - ../domain/cs2-data-attributes.md
status: draft
decision_status: proposed
date: 2026-04-25
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-001: CS2 Data Acquisition Source Strategy

## Контекст

`PRD-001` требует зафиксировать для baseline ingestion-layer явные `primary source`, `fallback policy`, правила freshness и provenance по ключевым CS2 `entity families`: матчи, расписание, турниры, команды, игроки, составы, рейтинги, новости и трансферы.

Для выбора стратегии были повторно проверены актуальные публичные условия основных источников на `2026-04-25`.

### Краткий анализ источников

| Источник | Какие сущности и атрибуты покрывает | История данных | Обновление | Стабильность и интеграция | Ограничения и риски |
| --- | --- | --- | --- | --- | --- |
| `PandaScore` | матчи, расписание, турниры, команды, игроки, tournament rosters, post-match scores, часть stats | публично заявляет `6 years history`; historical/post-match доступ зависит от плана | fixtures обновляются оперативно; live и replay доступны на live-планах | официальный REST/WebSocket API, документированная схема, лучший DX | free plan `1000 req/hour`; `Historical` от `400€/game/month`; `Live` от `1000€/game/month`; round/event feed только на real-time/live планах; stats-планы недоступны для betting usage без отдельного согласования |
| `HLTV` | HLTV ranking, rich match context, veto, roster timeline, team/player pages, transfers/news context | глубокая историчность по CS, фактически эталонный архив сцены | ranking обновляется еженедельно; match pages и новости обновляются оперативно | официального публичного API нет; интеграция только через scraping/неофициальные wrappers | высокий риск anti-bot/Cloudflare и IP bans; нет контрактной схемы; юридическая база слабее API-источников |
| `Liquipedia` | teams, players, tournaments, matches, standings, transfers, roster history | публично заявляет `15+ years` исторических данных | публично заявляет `5000+ daily updates`; есть webhooks в коммерческом API | официальный API-family, но доступ и лимиты жестко регулируются | HTML scraping запрещен; `LiquipediaDB` только по approved request и `60 req/hour`; `MediaWiki API` `1 req/2 sec`; обязательны cache и attribution; betting-related projects не принимаются |
| `Valve Regional Standings` | snapshots VRS, региональные standings, invite semantics, модель рейтинга | история ограничена эпохой VRS и публикациями в репозитории | standings обновляются `periodically` до open qualifiers | официальный и канонический источник для `valve_regional_standings` | не покрывает матчи, ростеры и общую entity-базу; формат данных узкий |
| `BO3.gg` | матчи, live-статистика, player/team pages, transfers, round-level presentation | глубокая история заявлена на сайте, но без формального API-контракта | live-ориентированное обновление | как сайт удобен для исследования, но интеграция не подтверждена публичной API-документацией | неясны pricing, rate limits, легальность массового использования и устойчивость доступа; по рискам близок к scraping-source |

### Сопоставление покрытия по `entity families` ingestion

`Entity families` для сравнения: `matches/schedule`, `tournaments/bracket`, `teams/players`, `tournament rosters`, `HLTV ranking`, `Valve VRS`, `membership history / transfers`, `veto`, `round history`.

| Источник | Полностью закрывает | Частично закрывает | Не закрывает |
| --- | --- | --- | --- |
| `PandaScore` | `matches/schedule`, `tournaments/bracket`, `teams/players`, `tournament rosters` | `round history` | `HLTV ranking`, `Valve VRS`, `membership history / transfers`, `veto` |
| `HLTV` | `HLTV ranking`, `veto` | `matches/schedule`, `tournaments/bracket`, `teams/players`, `membership history / transfers` | `tournament rosters`, `Valve VRS`, `round history` |
| `Liquipedia` | `membership history / transfers` | `matches/schedule`, `tournaments/bracket`, `teams/players`, `tournament rosters` | `HLTV ranking`, `Valve VRS`, `veto`, `round history` |
| `Valve Regional Standings` | `Valve VRS` | none | `matches/schedule`, `tournaments/bracket`, `teams/players`, `tournament rosters`, `HLTV ranking`, `membership history / transfers`, `veto`, `round history` |
| `BO3.gg` | none | `matches/schedule`, `tournaments/bracket`, `teams/players`, `membership history / transfers`, `round history` | `tournament rosters`, `HLTV ranking`, `Valve VRS`, `veto` |

Главный вывод исследования: ни один источник в одиночку не закрывает baseline без критичных пробелов. Единственная practical foundation-комбинация для первого этапа: `PandaScore + Valve`, с опциональным `HLTV` и `Liquipedia` для узких `entity families`, где baseline API не хватает глубины.

## Драйверы решения

- Нужен source stack, который дает production-like baseline без зависимости от scraping как от системной основы.
- Для `TRS-03 = valve_regional_standings` нужен официальный source-of-truth, а не агрегатор.
- Для матчей, турниров, команд, игроков и roster participation нужен документированный API с повторяемым ingestion.
- Для `MEM-*`, `transfers` и `VTO-*` допустим enrichment-path, но он не должен блокировать baseline ingestion.
- Нужна явная граница между guaranteed phase-1 `entity families` и conditional расширениями, чтобы delivery-gates не зависели от оценочных формулировок.
- Нужно минимизировать юридический и операционный риск для betting-adjacent продукта.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему рассматривается как основной кандидат / не основной кандидат |
| --- | --- | --- | --- |
| `PandaScore only` | официальный API, лучший DX, хорошо закрывает baseline по матчам и турнирам | не закрывает VRS, слабо закрывает membership-history и veto, round history платная | сильный baseline-кандидат, но один не закрывает весь required scope |
| `HLTV first` | сильнейший CS-specific coverage, ranking, veto, rich context | нет официального API, высокий anti-bot риск, слабая контрактность | не основной кандидат из-за operability и legal risk |
| `Liquipedia first` | глубокая история, roster/transfers, широкий esports coverage | жесткие ограничения доступа, betting-related проекты не принимаются, HTML scraping запрещен | не основной кандидат для foundation, годится только как approved secondary source |
| `Hybrid: PandaScore + Valve + HLTV/Liquipedia by need` | закрывает baseline через API, сохраняет каноничность VRS, оставляет enrichment для gaps | сложнее orchestration, нужен per-category provenance и conflict resolution | основной кандидат, потому что это единственный вариант без критичной зависимости от scraping и с приемлемым coverage |
| `BO3.gg as reserve source` | потенциально глубокая live и round-level глубина | нет подтвержденного публичного API-контракта, высокий риск повторить проблемы HLTV | не основной кандидат, только research fallback |

## Решение

Предлагается принять гибридную стратегию:

- `PandaScore` использовать как `primary source` для `matches/schedule`, `tournaments/bracket`, `teams/players`, `tournament rosters` и baseline post-match scores.
- `Valve Regional Standings` использовать как отдельный `primary source` только для `TRS-03 = valve_regional_standings`, invite semantics и связанных snapshot-данных.
- `HLTV` использовать только как `controlled enrichment/fallback` для `HLTV ranking`, `veto`, части roster timeline и match-context данных, где baseline API не дает нужной глубины.
- `Liquipedia` использовать только как `optional approved source` для `membership history / transfers` и identity-resolution support, если юридически и коммерчески доступ подтвержден.
- `BO3.gg` не включать в canonical priority list первого этапа; держать только как резервный research candidate на случай, если later-stage потребуются round-level данные без приемлемого доступа у `PandaScore`.

### Scope contract для phase 1

Этот ADR фиксирует точный критерий, который в `PRD-001` был оставлен как conditional rule для `tournaments/maps/veto`. Для delivery-gates phase 1 используется следующая рамка:

| Пакет phase 1 | `Entity families` | Статус в phase 1 | Правило включения |
| --- | --- | --- | --- |
| `Guaranteed baseline package` | `teams`, `players`, `matches/schedule`, `tournaments/bracket`, `tournament rosters`, `team ranking snapshots` с обязательной поддержкой `TRS-03 = valve_regional_standings` | обязательно | входит в definition of done phase 1 без дополнительных условий |
| `Conditional extension package` | `maps`, `veto` | условно | входит в phase 1 только если проходит `API-ingestion simplicity gate`, зафиксированный ниже |
| `Optional enrichment package` | `membership history / transfers`, `HLTV ranking` | желательно, но не блокирует baseline launch | может быть доставлен в phase 1 или после него отдельным slice |

`API-ingestion simplicity gate` считается пройденным только если одновременно выполнены все условия:

1. Для `entity family` существует документированный API-источник с повторяемым доступом без обязательного HTML scraping как единственного пути.
2. Этот источник покрывает минимальный `canonical attributes` set, достаточный для storage-модели из `CS2 Data Attributes`.
3. Интеграция не требует live-only или enterprise-only договорённостей, без которых ingestion не может быть воспроизведён в baseline-режиме.
4. Для данных можно зафиксировать `primary source`, допустимый fallback и provenance semantics без ad hoc ручной интерпретации на каждом run.

Если хотя бы одно из условий не выполнено, `maps` и `veto` не входят в definition of done phase 1 и оформляются как отдельный downstream slice.

Как планируем использовать выбранные источники:

- canonical entity bootstrap и регулярные обновления матчей строятся вокруг `PandaScore`;
- VRS snapshots хранятся отдельно, без попытки нормализовать их как производные от стороннего рейтинга;
- данные из `HLTV` и `Liquipedia` всегда сохраняются как source-scoped snapshots с provenance и не считаются uncontested truth без source-priority rules;
- `MEM-*`, `transfers` и `HLTV ranking` считаются optional enrichment `entity families` первого этапа, а не blocker для baseline launch;
- `VTO-*` относится к conditional extension package и становится частью phase 1 только при прохождении `API-ingestion simplicity gate`;
- новости не входят в рекомендуемую source-комбинацию этого ADR и должны быть оформлены отдельным downstream-решением.

Fallback-план:

- если недоступен `PandaScore`, baseline-сбор матчей и турниров временно деградирует до partial mode: `Liquipedia` для tournament/match context и `HLTV` для schedule/result sanity check, без обещания полной консистентности;
- если недоступен `Valve`, last known VRS snapshots сохраняются read-only до восстановления официального источника;
- если недоступен `HLTV`, отключаются только enrichment pipelines `HLTV ranking` и conditional `veto`, без остановки baseline ingestion;
- если `Liquipedia` не дает approval или блокирует доступ, membership-history остается частично неполной до появления другого approved source.

## Последствия

### Положительные

- Первый этап получает устойчивый foundation на документированном API, а не на scraping-first подходе.
- `Valve` фиксируется как канонический источник для VRS, что убирает ambiguity по `TRS-03`.
- ADR теперь явно разделяет guaranteed baseline, conditional extension и optional enrichment packages, так что phase-1 delivery-gates не зависят от оценочных формулировок.
- Gaps по `veto`, `membership history` и `round history` отделяются от baseline и не тормозят запуск ingestion-layer.

### Отрицательные

- Появляется multi-source orchestration и необходимость per-`entity family` conflict resolution.
- `HLTV` и `Liquipedia` нельзя считать гарантированно доступными production-сигналами.
- Для полной глубины исторических и round-level данных возможны заметные recurring costs у `PandaScore`.

### Нейтральные / организационные

- Downstream feature packages должны явно фиксировать source priority по `entity families` и `canonical attributes`.
- Для каждого ingestion job нужно хранить provenance, freshness и `complete/partial/failed` статус.
- Membership-history и veto нужно проектировать как optional feature slices с отдельной verify-логикой.

## Риски и mitigation

- Риск: продукт останется зависимым от платных планов `PandaScore` для глубоких stats и round history.
  Mitigation: baseline scope ограничить fixtures, tournaments, teams, players, rosters и source-reported scores; round-level данные не обещать без отдельной валидации тарифа.
- Риск: `HLTV` будет блокировать scraping или менять HTML.
  Mitigation: держать `HLTV` вне critical path и rate-limitить enrichment jobs.
- Риск: `Liquipedia` окажется недоступной для use-case проекта.
  Mitigation: считать ее optional integration и не завязывать на нее canonical baseline.
- Риск: идентичности команд и игроков разойдутся между источниками.
  Mitigation: сразу проектировать source mapping и identity resolution как отдельный downstream capability.
- Риск: downstream-команды будут по-разному трактовать, входит ли `maps/veto` в phase 1.
  Mitigation: считать этот вопрос закрытым данным ADR; delivery-gates опираются на таблицу phase-1 packages и `API-ingestion simplicity gate`, а не на свободную интерпретацию PRD.

## Follow-up

- Оформить feature-level source priority matrix по ключевым категориям ingestion.
- Зафиксировать verify-контракт на provenance, freshness и partial ingestion result.
- Отдельно решить источник для news ingestion.
- Отдельно подтвердить коммерческую и юридическую применимость `PandaScore` и `Liquipedia` для use-case проекта до production rollout.

## Связанные ссылки

- [PRD-001: Internet Data Acquisition](../prd/PRD-001-internet-data-acquisition.md)
- [CS2 Data Attributes](../domain/cs2-data-attributes.md)
- [PandaScore pricing](https://www.pandascore.co/pricing)
- [PandaScore tournaments in-depth](https://developers.pandascore.co/docs/tournaments-in-depth)
- [PandaScore CS rounds endpoint](https://developers.pandascore.co/reference/get_csgo_games_csgogameid_rounds-1)
- [Liquipedia API Terms of Use](https://liquipedia.net/api-terms-of-use)
- [Liquipedia API](https://liquipedia.net/api)
- [Liquipedia Counter-Strike main page](https://liquipedia.net/counterstrike/Main_Page)
- [Valve Regional Standings repository](https://github.com/ValveSoftware/counter-strike_regional_standings)
- [Valve Major Supplemental Rulebook](https://github.com/ValveSoftware/counter-strike_rules_and_regs/blob/main/major-supplemental-rulebook.md)
- [HLTV Terms of Service](https://www.hltv.org/terms)
- [HLTV team page example with ranking and roster timeline](https://www.hltv.org/team/12457/rounds)
- [HLTV stats pages](https://www.hltv.org/stats)
- [HLTV map/veto stats example](https://www.hltv.org/stats/teams/maps/10717/veto?csVersion=CS2)
- [PandaScore Introduction](https://developers.pandascore.co/docs/introduction)
- [PandaScore FAQ](https://developers.pandascore.co/docs/frequently-asked-questions)
