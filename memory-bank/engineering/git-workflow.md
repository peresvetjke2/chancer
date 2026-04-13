---
title: Git Workflow
doc_kind: engineering
doc_function: convention
purpose: Шаблон git workflow документа. После копирования зафиксируй реальные branch names, commit rules и PR expectations проекта.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Git Workflow

## Default Branch

Основной `branch` - `main`.

## Commits

- Present-tense, concise (`fix: normalize cache key`)

## Pull Requests

- Перед PR должны быть зелёными canonical local checks проекта
- PR title должен быть коротким и предметным
- В body полезно фиксировать: что изменено, как проверено, какие риски или manual steps остаются
