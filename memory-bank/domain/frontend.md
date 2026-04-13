---
title: Frontend
doc_kind: domain
doc_function: canonical
purpose: Описание UI-поверхностей, стека и соглашений по frontend. Читать при работе с web-интерфейсом.
derived_from:
  - ../dna/governance.md
  - problem.md
status: active
audience: humans_and_agents
---

# Frontend

## UI Surfaces

Единственная поверхность — web-приложение:

- **Чат-интерфейс** — свободные запросы пользователя на естественном языке, ответы от AI-помощника.
- **Лента матчей** — список предстоящих матчей CS2 с быстрым прогнозом.

Код:

- Views: `app/views/`
- JavaScript: `app/javascript/`
- Стили: `app/assets/stylesheets/`

Backend boundary: Rails-контроллеры, обычный HTTP-цикл запрос/ответ.

Авторизация пользователей вне scope (`PCON-01`).

## Component And Styling Rules

Design system отсутствует. CSS-фреймворк не используется.

- Стили — в `app/assets/stylesheets/application.css`.
- JavaScript-поведение — Stimulus-контроллеры в `app/javascript/controllers/`.
- Ad hoc CSS допустим; отдельные файлы по стилям не регламентированы на текущем этапе.

## Interaction Patterns

Stack: Rails ERB + Hotwire (Turbo + Stimulus) + importmap.

Чат реализован максимально просто: стандартный HTTP form submit, ответ — перерисовка страницы через Turbo. Real-time (Turbo Streams, WebSocket) не используется.

Правила:

- Новые интерактивные элементы строятся на Stimulus; не вводить альтернативный JS-фреймворк без явного решения.
- Bundler не используется — только importmap; новые npm-пакеты добавляются только по согласованию.

## Localization

Локализация вне scope. Интерфейс — только на русском языке. i18n-инфраструктура не подключена.
