# Spec: Load Team Matches (#2)

## Scope

**In:**
- Скрапинг результатов матчей с HLTV за последние 30 дней для всех команд из БД
- Сохранение: `matches` + `map_results`
- Rake task для запуска вручную

**Out:**
- `player_stats` — отдельная задача
- Матчи будущих периодов / расписание
- Команды не из БД (Teams scraper — отдельная задача)

---

## Решения

| Вопрос | Решение |
|---|---|
| Источник | HLTV `/results?team=<hltv_id>` (Selenium, как в Teams scraper) |
| Период | 30 дней назад от даты запуска |
| Дедупликация | Добавить `hltv_id integer` в `matches` (новая миграция); upsert по нему |
| Оппонент не в БД | `find_or_create_by(hltv_id:) { \|t\| t.name = name_from_page }` — только `hltv_id` + `name`, остальные поля nil |
| Карты | Карты считаются недоступными, если блок `.mapholder` отсутствует или пустой — тогда `maps: []` |

---

## Требования к поведению

1. `Scrapers::Hltv::Matches.call(team:)` — принимает объект `Team`, возвращает массив хэшей:
   `hltv_id, played_at, team1_hltv_id, team2_hltv_id, winner_hltv_id, score, tournament, maps`
   где `maps` — массив `{map_name:, score:}`. Если матчей нет — возвращает `[]`.

2. Rake task `matches:load`:
   - Итерирует `Team.where.not(hltv_id: nil)`
   - Вызывает scraper для каждой команды, сохраняет результаты
   - Если scraper вернул `[]` — пропускает команду без лога

3. Матч сохраняется через `upsert` по `matches.hltv_id`. При повторном запуске дублей нет.

4. Если команда-оппонент отсутствует в БД — создаётся минимальная запись:
   ```ruby
   Team.find_or_create_by(hltv_id: opponent_hltv_id) { |t| t.name = opponent_name }
   ```

5. При ошибке парсинга одной команды — логируем и продолжаем:
   ```ruby
   Rails.logger.error "[matches:load] Failed for team #{team.hltv_id}: #{e.message}"
   ```
   `Scrapers::Hltv::Error` оборачивает: `Net::ReadTimeout`, HTTP 4xx/5xx от HLTV, `Selenium::WebDriver::Error::*`. Retry не предусмотрен.

---

## Инварианты

- Не трогать существующие миграции
- Паттерн скрапера: `Scrapers::Hltv::ClassName`, тот же стиль что `Teams`
- Selenium headless Chrome (без новых гемов)
- Тесты используют fixture HTML, без реальных запросов к HLTV

---

## Acceptance Criteria

- [ ] `bundle exec rake matches:load` завершается без ошибок при наличии хотя бы одной команды в БД
- [ ] После запуска `Match.where('played_at >= ?', 30.days.ago).count > 0`
- [ ] Повторный запуск не создаёт дублей (count стабилен)
- [ ] `match.map_results` содержит записи если HLTV вернул данные по картам
- [ ] RSpec: для fixture `hltv_match_results.html` scraper возвращает массив; первый элемент содержит ожидаемые значения `hltv_id`, `score`, `maps` (конкретные значения определяются по fixture)
- [ ] RSpec: rake task сохраняет данные в БД (интеграционный тест с реальной БД)
- [ ] RSpec: команда без `hltv_id` пропускается rake task'ом (не передаётся в scraper)

---

## Изменения в схеме

```
add_column :matches, :hltv_id, :integer
add_index  :matches, :hltv_id, unique: true
```
