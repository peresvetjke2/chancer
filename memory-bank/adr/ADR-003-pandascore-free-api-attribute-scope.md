---
title: "ADR-003: PandaScore Free API Attribute Scope"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует перечень сущностей и атрибутов, которые допустимо забирать из PandaScore в рамках бесплатного плана, с обязательной проверяемой ссылкой на источник."
derived_from:
  - ../prd/PRD-002-pandascore-data-acquisition.md
status: draft
decision_status: approved
date: 2026-04-26
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-003: PandaScore Free API Attribute Scope

## Контекст

`PRD-002` требует явно зафиксировать baseline scope PandaScore по сущностям, атрибутам и ограничениям источника. Без этого downstream-реализация будет опираться на случайно замеченные поля API, а не на проверяемый контракт.

Дополнительное ограничение: использовать можно только бесплатный PandaScore API. Значит, ADR должен разделить:

- что можно считать разрешенным baseline для free plan;
- что относится к paid-only данным и не должно попадать в baseline-контракт;
- на какой официальный источник опирается каждое утверждение.

## Драйверы решения

- `PRD-002` требует определить минимально обязательный набор сущностей и атрибутов.
- Пользоваться нужно только проверяемыми данными из официальной документации PandaScore.
- Free plan у PandaScore ограничен `Schedules, Results & Context Data` и rate limit `1k requests per hour`.
- Нельзя включать в baseline post-match statistics, live frames и другие данные, требующие Historical или Live план.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Почему рассматривается как основной кандидат / не основной кандидат |
| --- | --- | --- | --- |
| `Широкий scope по всем полям, замеченным в API` | Максимум данных | Непроверяемо, высокий риск включить paid-only или нестабильные поля | Не основной кандидат |
| `Только сущности без атрибутного списка` | Быстро и безопасно | Не закрывает требование PRD по attribute scope | Не основной кандидат |
| `Whitelist сущностей и атрибутов с source links, ограниченный free plan` | Проверяемо, подходит для product contract, снижает риск выдуманных полей | Консервативно, часть полезных данных придется добавить позже отдельным ADR | Основной кандидат |

## Решение

Для `decision_status: proposed` предлагается считать baseline-контрактом только те сущности и атрибуты, которые одновременно:

- упомянуты в официальной документации PandaScore;
- доступны через endpoints, помеченные как `available to all customers`, либо явно описаны как часть бесплатного Fixtures/Context плана;
- не относятся к Historical Data или Live API.

### 1. Разрешенные baseline-сущности free plan

| Сущность | Что разрешено забирать | Почему это в baseline | Источник |
| --- | --- | --- | --- |
| `match` | список матчей CS2 через `/csgo/matches` и статусные выборки `past`, `running`, `upcoming` | это ядро acquisition scope из `PRD-002`; endpoint доступен всем | https://developers.pandascore.co/reference/get_csgo_matches-1 , https://developers.pandascore.co/reference/get_csgo_matches_past-1 , https://developers.pandascore.co/reference/get_csgo_matches_running-1 , https://developers.pandascore.co/reference/get_csgo_matches_upcoming-1 |
| `team` | список команд CS2 через `/csgo/teams` | входит в pre-match/context data и нужен для opponents / identity | https://developers.pandascore.co/reference/get_csgo_teams-1 |
| `player` | список игроков CS2 через `/csgo/players` | входит в pre-match/context data и нужен для roster / identity | https://developers.pandascore.co/reference/get_csgo_players-1 |
| `tournament` | список турниров CS2 и детальный турнир | турнир является родителем матчей и lowest level abstraction для child matches | https://developers.pandascore.co/reference/get_csgo_tournaments-1 , https://developers.pandascore.co/reference/get_tournaments_tournamentidorslug , https://developers.pandascore.co/docs/tournaments-in-depth |
| `tournament_roster` | состав участников турнира через `expected_roster` и `/tournaments/{id}/rosters` | docs прямо рекомендуют roster как источник участников турнира | https://developers.pandascore.co/docs/tournaments-in-depth , https://developers.pandascore.co/reference/get_tournaments_tournamentidorslug_rosters |
| `league` | league context и связи игрока/команды с league | league - верхний уровень и часть competition context | https://developers.pandascore.co/docs/fundamentals , https://developers.pandascore.co/reference/get_leagues , https://developers.pandascore.co/reference/get_players_playeridorslug_leagues , https://developers.pandascore.co/reference/get_teams_teamidorslug_leagues |
| `serie` | serie context как временное вхождение внутри league | docs описывают serie как обязательный уровень иерархии | https://developers.pandascore.co/docs/fundamentals , https://developers.pandascore.co/reference/get_series_serieidorslug_tournaments |
| `map` | справочник карт CS2 | endpoint доступен всем и полезен как controlled vocabulary | https://developers.pandascore.co/reference/get_csgo_maps-1 |

### 2. Разрешенные baseline-атрибуты free plan

Ниже перечислены только те атрибуты, которые удалось подтвердить официальной документацией. Если атрибут не указан в этой таблице, он не должен считаться частью baseline-контракта.

| Сущность | Разрешенные атрибуты / отношения | Основание | Источник |
| --- | --- | --- | --- |
| `match` | `name` / название матча | docs по Fixtures прямо называют match name частью free fixtures data | https://developers.pandascore.co/docs |
| `match` | scheduled time / запланированное время матча | docs по Fixtures прямо называют scheduled time частью free fixtures data | https://developers.pandascore.co/docs |
| `match` | format / формат матча, например bo3/bo5 | docs по Fixtures прямо называют format частью free fixtures data | https://developers.pandascore.co/docs |
| `match` | opponents / участники матча | docs по Fixtures прямо называют team opponents частью free fixtures data | https://developers.pandascore.co/docs |
| `match` | live streams / ссылки на трансляции | docs по Fixtures прямо называют live streams частью free fixtures data | https://developers.pandascore.co/docs |
| `match` | факт начала / завершения матча | docs говорят, что fixtures updates сообщают when a match begins or ends | https://developers.pandascore.co/docs |
| `match` | final score / финальный счет | docs относят final match score к fixtures updates | https://developers.pandascore.co/docs |
| `match` | winning team / победитель матча | docs относят winning team к fixtures updates | https://developers.pandascore.co/docs |
| `match` | принадлежность к `tournament` | docs описывают tournament как родителя child matches | https://developers.pandascore.co/docs/fundamentals , https://developers.pandascore.co/docs/tournaments-in-depth |
| `team` | `image_url` | FAQ и image docs прямо подтверждают наличие `image_url` у team | https://developers.pandascore.co/docs/frequently-asked-questions , https://developers.pandascore.co/docs/image-optimization |
| `team` | участие в матчах, турнирах, league/serie context | это подтверждается доступными all-customers endpoints для team matches/series/tournaments/leagues | https://developers.pandascore.co/reference/get_teams_teamidorslug_leagues , https://developers.pandascore.co/reference/get_teams_teamidorslug_matches , https://developers.pandascore.co/reference/get_teams_teamidorslug_series , https://developers.pandascore.co/reference/get_teams_teamidorslug_tournaments |
| `player` | `age` | docs прямо описывают поле `age` в player object | https://developers.pandascore.co/docs/about-players-age |
| `player` | `birthday` | docs прямо описывают поле `birthday` в player object | https://developers.pandascore.co/docs/about-players-age |
| `player` | `image_url` | FAQ прямо подтверждает наличие `image_url` у players | https://developers.pandascore.co/docs/frequently-asked-questions |
| `player` | team history через `/players/{id}/tournaments` | FAQ прямо рекомендует этот endpoint как самый надежный способ увидеть team history | https://developers.pandascore.co/docs/frequently-asked-questions , https://developers.pandascore.co/reference/get_players_playeridorslug_tournaments |
| `tournament` | `expected_roster` | docs прямо говорят, что Get a Tournament содержит `expected_roster` | https://developers.pandascore.co/docs/tournaments-in-depth |
| `tournament` | `rosters` | docs прямо говорят, что Get Rosters for a Tournament возвращает `rosters` | https://developers.pandascore.co/docs/tournaments-in-depth , https://developers.pandascore.co/reference/get_tournaments_tournamentidorslug_rosters |
| `tournament` | `has_bracket` | docs прямо описывают поле `has_bracket` на уровне турнира | https://developers.pandascore.co/docs/tournaments-in-depth |
| `tournament` | `previous_matches` в bracket context | docs прямо описывают `previous_matches` в tournament brackets endpoint | https://developers.pandascore.co/docs/tournaments-in-depth |
| `league` | `image_url` | FAQ прямо подтверждает наличие `image_url` у leagues | https://developers.pandascore.co/docs/frequently-asked-questions |
| `map` | `id`, `name` | docs по Counter-Strike frames прямо упоминают объект `map` c `id` и `name`; справочник maps доступен всем | https://developers.pandascore.co/docs/data-sample-csgo , https://developers.pandascore.co/reference/get_csgo_maps-1 |

### 2.1. Связь с `memory-bank/domain/cs2-data-attributes.md`

Ниже зафиксировано, для каких доменных атрибутов данные можно получить из PandaScore free plan, а для каких нельзя или можно только косвенно.

| ID | Атрибут | Может быть получен из Panda free plan | Как |
| --- | --- | --- | --- |
| `MCH-01` | Запланированное время матча | да | Прямо из free fixtures match schedule / scheduled time. |
| `MCH-02` | Формат матча (`Bo1/Bo3/Bo5`) | да | Прямо из free fixtures match format. |
| `MCH-03` | Статус матча | частично | Из lifecycle match begins / ends и status-like данных fixtures; нужен source-to-domain mapping rule. |
| `MCH-04` | Участники матча | да | Прямо из free fixtures team opponents. |
| `MCH-05` | Турнир матча | да | Через parent tournament relation у match / tournament context. |
| `MCH-06` | Стадия турнира для матча | нет | В использованных free docs нет явного подтверждения field-level атрибута для match stage. |
| `MCH-07` | Детализация стадии / раунд сетки | частично | Косвенно из tournament bracket context и `previous_matches`, но не как явно подтвержденный простой match field. |
| `MCH-08` | Причина / пометка статуса матча | нет | В использованных free docs нет явного подтверждения такого атрибута. |
| `MCH-09` | Итоговый счёт матча, полученный из источника | да | Прямо из free fixtures final match score. |
| `MCH-10` | Итоговый счёт матча, пересчитанный системой | нет | Это derived-атрибут нашей системы, не source field PandaScore. |
| `MAP-01` | Название карты | да | Из map object / maps dictionary, явно подтверждено `name`. |
| `MAP-02` | Матч карты | нет | В free baseline docs нет подтвержденного contract для map-to-match storage на нужной нам глубине. |
| `MAP-03` | Порядок карты в серии | нет | Требует game-level/post-match structure; в free baseline не подтверждено. |
| `MAP-04` | Счёт карты, полученный из источника | нет | Это относится к game-level/post-match detail, не подтверждено для free baseline. |
| `MAP-05` | Счёт карты, пересчитанный системой | нет | Это derived-атрибут нашей системы. |
| `MAP-06` | Стартовые стороны команд на карте | нет | Требует in-game / game-level detail; в free baseline не подтверждено. |
| `MAP-07` | История раундов на карте | нет | Требует round/event-level data; free baseline это не покрывает. |
| `VTO-01` | Матч veto-события | нет | В использованных free docs нет подтверждения veto data. |
| `VTO-02` | Команда-инициатор действия (`initiator_team_ref_or_null`) | нет | В использованных free docs нет подтверждения veto data. |
| `VTO-03` | Порядок действия | нет | В использованных free docs нет подтверждения veto data. |
| `VTO-04` | Тип действия | нет | В использованных free docs нет подтверждения veto data. |
| `VTO-05` | Карта действия | нет | В использованных free docs нет подтверждения veto data. |
| `TRN-01` | Название турнира | нет | Endpoint турниров доступен, но в использованных docs нет явного field-level подтверждения названия как baseline-атрибута. |
| `TRN-02` | Tier турнира | нет | В used docs есть упоминание tiers на обзорном уровне, но без явного подтвержденного field contract для free baseline. |
| `TRN-03` | Тип проведения (`LAN/online`) | нет | В использованных free docs нет явного подтверждения такого атрибута. |
| `TRN-04` | Регион проведения турнира (`event_region`) | нет | В использованных free docs нет явного подтверждения такого атрибута. |
| `TEM-01` | Название команды | нет | Endpoint команды доступен, но в использованных docs нет явного field-level подтверждения названия как baseline-атрибута. |
| `TEM-02` | Соревновательный регион команды (`competitive_region`) | нет | В использованных free docs нет явного подтверждения такого атрибута. |
| `TRS-01` | Команда рейтинга | нет | Рейтинги не входят в подтвержденный free Panda baseline. |
| `TRS-02` | Время снимка рейтинга | нет | Рейтинги не входят в подтвержденный free Panda baseline. |
| `TRS-03` | Рейтинговая система | нет | Рейтинги не входят в подтвержденный free Panda baseline. |
| `TRS-04` | Позиция в рейтинге | нет | Рейтинги не входят в подтвержденный free Panda baseline. |
| `TRS-05` | Значение рейтинга / очки | нет | Рейтинги не входят в подтвержденный free Panda baseline. |
| `ROS-01` | Актуальный состав | частично | Косвенно через `expected_roster` / `rosters`; нужен derivation rule для нашего roster snapshot. |
| `ROS-02` | Дата последнего изменения состава | нет | Не подтверждено как source field; это агрегат над membership history. |
| `MEM-01` | Команда | частично | Можно вывести из tournament roster / player tournament history, но не как единый явный membership field contract. |
| `MEM-02` | Игрок | частично | Можно вывести из tournament roster / player tournament history, но не как единый явный membership field contract. |
| `MEM-03` | Дата вступления в команду | нет | В использованных free docs нет явного подтверждения. |
| `MEM-04` | Дата ухода из команды | нет | В использованных free docs нет явного подтверждения. |
| `MEM-05` | Роль в составе | нет | В использованных free docs нет явного подтверждения. |
| `MEM-06` | Статус membership | нет | В использованных free docs нет явного подтверждения. |
| `MEM-07` | Период действия membership | нет | Это derived-атрибут; free docs не дают прямого contract для него. |
| `PLY-01` | Ник игрока | нет | Endpoint игроков доступен, но в использованных docs нет явного field-level подтверждения nickname как baseline-атрибута. |
| `PLY-02` | Основная роль игрока (`primary_role`) | нет | В использованных free docs нет явного подтверждения. |
| `PLY-03` | Дата рождения игрока | да | Прямо из player field `birthday`. |
| `PLY-04` | Национальность игрока | нет | В использованных free docs нет явного подтверждения. |

### 3. Явно запрещенные для baseline данные

Следующие данные не входят в baseline-контракт даже если технически могут существовать в API или примерах:

| Категория | Почему запрещено в baseline | Источник |
| --- | --- | --- |
| post-match player/team statistics | доступны только в Historical plan и выше | https://developers.pandascore.co/docs , https://developers.pandascore.co/reference/get_csgo_matches_matchidorslug_players_stats-1 |
| live frames / live events / websocket feeds | относятся к Live API, не к free fixtures plan | https://developers.pandascore.co/docs , https://developers.pandascore.co/docs/rate-and-connections-limits |
| detailed in-game / game-level historical results как baseline-обязательство | docs относят game-level results к Historical Data-supporting videogames, а не к free fixtures baseline | https://developers.pandascore.co/docs/fundamentals , https://developers.pandascore.co/docs |
| videogame logos | FAQ прямо говорит, что они не выдаются API | https://developers.pandascore.co/docs/frequently-asked-questions |

### 4. Эксплуатационные ограничения free plan

| Ограничение | Значение | Источник |
| --- | --- | --- |
| plan scope | `Schedules, Results & Context Data` / future and past match schedule / pre-match data on tournaments, teams, players | https://www.pandascore.co/pricing |
| бесплатность | free plan available to all users | https://developers.pandascore.co/docs , https://www.pandascore.co/pricing |
| REST rate limit | `1k requests per hour` | https://developers.pandascore.co/docs/rate-and-connections-limits , https://www.pandascore.co/pricing |
| change tracking | incidents доступны для `Leagues`, `Series`, `Tournaments`, `Matches`, `Teams`, `Players` | https://developers.pandascore.co/docs/tracking-changes |

### 5. Правило доказуемости

- Любой новый атрибут PandaScore может войти в baseline только после добавления в ADR явной ссылки на официальную документацию PandaScore.
- Если атрибут наблюдался только в живом ответе API, но не подтвержден docs/reference, он считается `unverified` и не должен использоваться как обязательный контракт.
- Если endpoint доступен only for Historical or Live plans, его поля не входят в free baseline даже при высокой полезности.

## Последствия

### Положительные

- Появляется консервативный и проверяемый whitelist для free PandaScore integration.
- `PRD-002` получает опору для baseline scope по сущностям и атрибутам.
- Снижается риск случайно завязаться на платные или недокументированные поля.

### Отрицательные

- Контракт намеренно уже, чем потенциально доступная фактическая структура ответов API.
- Некоторые полезные поля придется добавлять отдельным ADR после проверки по официальным источникам.

### Нейтральные / организационные

- Downstream feature docs должны ссылаться на этот ADR как на source-of-truth по free PandaScore scope.
- Verify checks должны различать `allowed-free`, `paid-only`, `unverified`.

## Риски и mitigation

- Риск: официальная документация может описывать сущность, но не перечислять все JSON-поля.
  Mitigation: baseline включать только то, что подтверждено текстом docs/reference; все остальное держать вне обязательного контракта.
- Риск: PandaScore изменит pricing или plan coverage.
  Mitigation: при изменении free plan обновлять ADR с новой датой и ссылкой на pricing/docs.
- Риск: часть downstream-задачам понадобятся post-match stats.
  Mitigation: оформлять это отдельным ADR про paid Historical plan, не размывая free baseline.

## Follow-up

- Обновить `PRD-002`, сославшись на этот ADR как на решение по baseline attribute scope.
- Создать downstream feature/spec, где mandatory fields будут выбраны только из whitelist этого ADR.
- В verify checks добавить классификацию полей: `free-allowed`, `paid-only`, `unverified`.

## Связанные ссылки

- [PRD-002: PandaScore Data Acquisition](../prd/PRD-002-pandascore-data-acquisition.md)
- PandaScore Introduction: https://developers.pandascore.co/docs
- PandaScore Pricing: https://www.pandascore.co/pricing
- PandaScore Rate limits: https://developers.pandascore.co/docs/rate-and-connections-limits
- PandaScore Fundamentals: https://developers.pandascore.co/docs/fundamentals
- PandaScore Tournaments in-depth: https://developers.pandascore.co/docs/tournaments-in-depth
- PandaScore FAQ: https://developers.pandascore.co/docs/frequently-asked-questions
