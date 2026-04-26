---
title: "ADR-002: CS2 Attribute-Level Source Matrix"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует рекомендуемых поставщиков данных по каждому canonical CS2-атрибуту и границы допустимых источников для phase 1 internet acquisition."
derived_from:
  - ../prd/PRD-001-internet-data-acquisition.md
  - ../domain/cs2-data-attributes.md
  - ./ADR-001-cs2-data-acquisition-source-strategy.md
status: archived
decision_status: rejected
date: 2026-04-26
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-002: CS2 Attribute-Level Source Matrix

> Архивировано: этот ADR отклонен и не должен использоваться как input для downstream-документов.

## Контекст

`PRD-001` требует определить `source-selection policy` для обязательных canonical attributes, а не только выбрать "хорошие сайты". Текущий `ADR-001` архивирован как `rejected`: он был полезен как первичный research, но не довел решение до уровня каждого атрибута из `memory-bank/domain/cs2-data-attributes.md`.

Дополнительное текущее ограничение scope: на момент этого ADR рассматривается только то, что можно получить через бесплатный API `PandaScore`. Все остальные варианты, включая другие API, официальные репозитории данных, scraping и платные vendor'ы, находятся вне объема текущего исследования и текущей реализации.

На `2026-04-26` по результатам проверки первичных источников картина такая:

- `PandaScore` дает документированный API для `matches`, `teams`, `players`, `tournaments`, `tournament rosters`, standings и части post-match данных; но round-level CS2 feed находится в live-tier, а не в baseline REST-пакете.
- Все прочие источники могут быть полезны для будущих этапов, но не участвуют в текущем scope, потому что текущий scope намеренно сужен до одного бесплатного API.

## Драйверы решения

- Нужен `attribute-level` выбор поставщика, совместимый с `BR-01`, `BR-03`, `BR-04`, `BR-05` из `PRD-001`.
- Текущий baseline должен быть реализуем только на `PandaScore free API`.
- Базовый слой должен работать без зависимости от scraping и без других внешних интеграций.
- Для `derived` атрибутов должен быть указан не внешний сайт, а источник истины, от которого производное значение считается системой.
- Надо отделить "атрибут покрывается текущим scope" от "атрибут теоретически существует у других поставщиков".
- Решение должно быть полезно для последующего design: ingest priority, provenance, partial/complete semantics.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему рассматривается как основной кандидат / не основной кандидат |
| --- | --- | --- | --- |
| `PandaScore free API only` | Документированный API, минимальный legal/operational risk, реализуемый узкий baseline | Большая часть domain attributes останется вне scope | Основной и единственный вариант текущего исследования |
| `PandaScore + другие бесплатные источники` | Теоретически шире coverage | Нарушает зафиксированное ограничение текущего scope | Не рассматривается в этом ADR |
| `Scraping-first` | Может закрыть отдельные gaps | Не соответствует текущему scope и policy | Не рассматривается в этом ADR |
| `Paid vendor extension` | Существенно лучшее coverage | Платный доступ, вне scope | Не рассматривается в этом ADR |

## Решение

Предлагается принять следующую source matrix.

### 1. Разрешенный пул поставщиков

| Код | Поставщик | Роль в системе | Сильные стороны | Основные ограничения |
| --- | --- | --- | --- | --- |
| `PDS` | `PandaScore` | baseline structured API | матчи, команды, игроки, турниры, tournament rosters, standings, post-match result layer | deep CS2 round/live данные не входят в baseline free/fixtures access |
| `INT` | `internal derivation` | derived-атрибуты | прозрачный источник истины | не внешний источник, а вычисление по raw-данным |

### 2. Явно запрещенные как canonical source

- Любой источник, кроме бесплатного API `PandaScore`, не использовать в текущем scope.
- Любой scraping не использовать в текущем scope.
- Любой платный источник не использовать в текущем scope.
- `Valve VRS`, `Liquipedia`, `HLTV`, `Bayes`, `Abios`, `GRID` и аналогичные провайдеры считать `out_of_current_scope`.

### 3. Attribute-Level Source Matrix

#### Матч

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `MCH-01` | Запланированное время матча | `PDS` | в текущем scope покрывается |
| `MCH-02` | Формат матча | `PDS` | в текущем scope покрывается |
| `MCH-03` | Статус матча | `PDS` | в текущем scope покрывается |
| `MCH-04` | Участники матча | `PDS` | в текущем scope покрывается |
| `MCH-05` | Турнир матча | `PDS` | в текущем scope покрывается |
| `MCH-06` | Стадия турнира для матча | `PDS` | покрывается настолько, насколько это отдает `PDS` |
| `MCH-07` | Детализация стадии / раунд сетки | `PDS` | допустим только как `best effort`; при отсутствии считать вне coverage |
| `MCH-08` | Причина / пометка статуса матча | `PDS` | покрывается настолько, насколько это отдает `PDS` |
| `MCH-09` | Итоговый счёт матча, полученный из источника | `PDS` | в текущем scope покрывается |
| `MCH-10` | Итоговый счёт матча, пересчитанный системой | `INT` | derived from map-level results |

#### Карта в серии

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `MAP-01` | Название карты | `out_of_current_scope` | карта как самостоятельная canonical сущность не входит в текущий scope |
| `MAP-02` | Матч карты | `out_of_current_scope` | |
| `MAP-03` | Порядок карты в серии | `out_of_current_scope` | |
| `MAP-04` | Счёт карты, полученный из источника | `out_of_current_scope` | |
| `MAP-05` | Счёт карты, пересчитанный системой | `INT` | derived from round history |
| `MAP-06` | Стартовые стороны команд на карте | `out_of_current_scope` | |
| `MAP-07` | История раундов на карте | `out_of_current_scope` | |

#### Veto

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `VTO-01` | Матч veto-события | `out_of_current_scope` | veto не входит в текущий scope |
| `VTO-02` | Команда-инициатор действия | `out_of_current_scope` | |
| `VTO-03` | Порядок действия | `out_of_current_scope` | |
| `VTO-04` | Тип действия | `out_of_current_scope` | |
| `VTO-05` | Карта действия | `out_of_current_scope` | |

#### Турнир

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `TRN-01` | Название турнира | `PDS` | canonical tournament label |
| `TRN-02` | Tier турнира | `PDS` | PandaScore tier system explicitly documented |
| `TRN-03` | Тип проведения (`LAN/online`) | `out_of_current_scope` | поле не обещается в текущем scope |
| `TRN-04` | Регион проведения турнира (`event_region`) | `PDS` | baseline event metadata source |

#### Команда

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `TEM-01` | Название команды | `PDS` | canonical team label |
| `TEM-02` | Соревновательный регион команды (`competitive_region`) | `out_of_current_scope` | поле не обещается в текущем scope |

#### Снимок рейтинга команды

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `TRS-01` | Команда рейтинга | `out_of_current_scope` | ranking snapshots не входят в текущий scope |
| `TRS-02` | Время снимка рейтинга | `out_of_current_scope` | |
| `TRS-03` | Рейтинговая система | `INT` | system enum задается нами по provenance источника |
| `TRS-04` | Позиция в рейтинге | `out_of_current_scope` | |
| `TRS-05` | Значение рейтинга / очки | `out_of_current_scope` | |

#### Состав команды

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `ROS-01` | Актуальный состав | `INT` | derived from membership history |
| `ROS-02` | Дата последнего изменения состава | `INT` | derived from membership history |

#### Membership игрока в команде

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `MEM-01` | Команда | `out_of_current_scope` | membership history не входит в текущий scope |
| `MEM-02` | Игрок | `out_of_current_scope` | |
| `MEM-03` | Дата вступления в команду | `out_of_current_scope` | |
| `MEM-04` | Дата ухода из команды | `out_of_current_scope` | |
| `MEM-05` | Роль в составе | `out_of_current_scope` | |
| `MEM-06` | Статус membership | `out_of_current_scope` | |
| `MEM-07` | Период действия membership | `INT` | derived from `MEM-03` and `MEM-04` |

#### Игрок

| ID | Атрибут | Поставщик | Комментарий |
| --- | --- | --- | --- |
| `PLY-01` | Ник игрока | `PDS` | canonical display label |
| `PLY-02` | Основная роль игрока (`primary_role`) | `out_of_current_scope` | поле не обещается в текущем scope |
| `PLY-03` | Дата рождения игрока | `PDS` | `birthday` documented in PandaScore |
| `PLY-04` | Национальность игрока | `PDS` | `nationality` documented in PandaScore |

### 4. Operational interpretation

- `PDS` является default `primary source` для phase-1 baseline structured ingestion.
- `PDS` является единственным внешним источником в текущем scope.
- `out_of_current_scope` означает, что атрибут не должен входить ни в текущую реализацию, ни в текущий исследовательский baseline.
- Если для атрибута указан `INT`, это означает, что внешний supplier определен на уровне source-of-truth raw fields, а persisted value вычисляется системой.
- Для `INT`-полей без покрывающих raw-атрибутов в `PDS` значение фактически не должно обещаться в текущем scope.

## Последствия

### Положительные

- Появляется пригодная для реализации матрица "атрибут -> поставщик", а не абстрактный список источников.
- Scope стал очень четким: текущая работа привязана только к `PandaScore free API`.
- Убирается соблазн расползтись в дополнительные источники и полу-исследовательские интеграции.
- `derived` поля перестают быть ambiguity-зоной: для них явно фиксируется `INT`.

### Отрицательные

- В текущем scope большая часть domain attributes сознательно исключена.
- Даже часть `derived` атрибутов остается неиспользуемой, если нет raw-данных из `PDS`.
- `VRS`, roster history, veto и round-level depth не исследуются дальше в рамках текущего объема.

### Нейтральные / организационные

- Verify-логика должна отличать `not returned by PandaScore` от `out_of_current_scope`.
- Нужно отдельно завести source catalog с `access path`, `rate limits`, `freshness SLA`, `license notes`.

## Риски и mitigation

- Риск: команда реализации решит "временно" закрыть gaps через второй источник.
  Mitigation: считать это нарушением данного ADR.
- Риск: `PDS` окажется недостаточно точным по отдельным tournament metadata fields.
  Mitigation: хранить provenance и разрешать targeted fallback только через одобренные источники, а не через generic scraping.
- Риск: текущий scope окажется слишком узким относительно исходного domain-документа.
  Mitigation: явно считать исключенные атрибуты `out_of_current_scope`, а не silently partial.

## Follow-up

- Если scope изменится, завести отдельный ADR по расширению beyond-`PandaScore`.
- Завести source catalog с колонками: `attribute_ids`, `access_mode`, `plan`, `license`, `freshness`, `fallback`.
- Уточнить в downstream verify contract, какие именно `PDS`-атрибуты считаются обязательными для текущего baseline.

## Связанные ссылки

- [PRD-001: Internet Data Acquisition](../prd/PRD-001-internet-data-acquisition.md)
- [CS2 Data Attributes](../domain/cs2-data-attributes.md)
- [ADR-001: CS2 Data Acquisition Source Strategy](./ADR-001-cs2-data-acquisition-source-strategy.md)
- [PandaScore Introduction](https://developers.pandascore.co/docs/introduction)
- [PandaScore Tournaments in-depth](https://developers.pandascore.co/docs/tournaments-in-depth)
- [PandaScore Match lifecycle](https://developers.pandascore.co/docs/matches-lifecycle)
- [PandaScore FAQ](https://developers.pandascore.co/docs/frequently-asked-questions)
- [PandaScore About players' age](https://developers.pandascore.co/docs/about-players-age)
- [PandaScore changelog 2.13.3](https://developers.pandascore.co/changelog/2133)
- [PandaScore pricing](https://www.pandascore.co/pricing)
