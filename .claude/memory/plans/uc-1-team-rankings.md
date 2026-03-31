# UC-1: Текущий рейтинг команд

**Источник данных:** hltv.org/ranking/teams  
**Вариант использования:** запрос TOP X (где X — входящий аргумент)

---

## Чек-лист реализации

### 1. Gemfile — проверить/добавить nokogiri
- [x] Убедиться, что `nokogiri` есть в Gemfile; добавить и запустить `bundle install` если отсутствует

**Критерий готовности:** `bundle exec ruby -e "require 'nokogiri'"` завершается без ошибок

---

### 2. Миграция `teams`
- [x] `rename_column :teams, :rating, :hltv_rank`
- [x] Добавить колонку `hltv_id` (integer, null: false, unique index)

**Критерий готовности:** `bin/rails db:migrate` проходит без ошибок; `bin/rails db:schema:dump` отражает новые колонки; `bundle exec rspec spec/models/` — все существующие тесты зелёные (миграция ничего не сломала)

---

### 3. Модель `Team`
- [x] Уникальный индекс по `hltv_id` (добавлен миграцией)
- [x] Валидация `validates :hltv_id, presence: true, uniqueness: true`

**Критерий готовности:** написаны тесты для новых валидаций (`hltv_id` presence, uniqueness) и атрибута `hltv_rank`; `bundle exec rspec spec/models/team_spec.rb` — все тесты зелёные

---

### 4. Фикстуры — обновить под новую схему
- [x] `spec/factories/teams.rb`: заменить `rating` → `hltv_rank`, добавить `hltv_id { 1 }` (sequence)

**Критерий готовности:** `bundle exec rspec spec/models/` — все существующие тесты зелёные (нет ошибок из-за переименования колонки)

---

### 5. `lib/scrapers/hltv/teams.rb`
- [x] Headless Chrome через `selenium-webdriver` (обход Cloudflare); заголовок `User-Agent`
- [x] Поднимать `Scrapers::Hltv::Error` при таймауте ожидания `.ranked-team`
- [x] Парсинг HTML через Nokogiri: извлечь `hltv_id`, `name`, `hltv_rank`, `region`
- [x] Принимать аргумент `limit:`, обрезать результат до TOP X
- [x] Возвращать `[]` при пустом результате (не падать)

**Критерий готовности:** `bundle exec rspec spec/lib/scrapers/hltv/teams_spec.rb` — покрыты: успешный парсинг, таймаут Selenium, пустой результат ✅

---

### 6. `app/services/teams/update_rankings.rb`
- [ ] Принимать массив хешей от скрапера
- [ ] При пустом массиве — логировать предупреждение и выходить без изменений в БД
- [ ] `upsert_all` по `hltv_id` — идемпотентно
- [ ] После upsert обнулять `hltv_rank` у команд, не вошедших в свежий список:
  ```ruby
  Team.where.not(hltv_id: scraped_hltv_ids).update_all(hltv_rank: nil)
  ```

**Критерий готовности:** `bundle exec rspec spec/services/teams/update_rankings_spec.rb` — покрыты: upsert новых, обновление существующих, обнуление выпавших, пропуск при пустом массиве

---

### 7. `lib/tasks/hltv.rake`
- [ ] Задача `hltv:update_rankings[limit]` вызывает скрапер и сервис
- [ ] Выводит результат (сколько команд обновлено) или сообщение об ошибке

**Критерий готовности:** `bin/rails hltv:update_rankings[5]` выполняется без исключений; в БД появляются/обновляются записи с `hltv_id` и `hltv_rank`

---

### 8. Спеки — итоговая проверка
- [ ] `spec/models/team_spec.rb` — тесты для `hltv_rank`, `hltv_id`, уникальности
- [ ] `spec/lib/scrapers/hltv/teams_spec.rb` — создать
- [ ] `spec/services/teams/update_rankings_spec.rb` — создать

**Критерий готовности:** `bundle exec rspec` — весь suite зелёный, нет pending
