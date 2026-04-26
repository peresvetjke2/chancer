Проведи критичное ревью ADR в файле `{ADR_PATH}` как decision record.

Используй только:
- сам ADR;
- `memory-bank/flows/templates/adr/ADR-XXX.md`;
- `memory-bank/dna/governance.md`;
- `memory-bank/dna/frontmatter.md`;
- `memory-bank/adr/README.md`;
- документы из `derived_from` и связанных ссылок, если они реально существуют.

Операционный контракт:
- считай template и governance source of truth;
- не дублируй их правила своими словами там, где можно сослаться на них напрямую;
- для каждого вывода явно помечай тип evidence: `fact` | `inference` | `missing`;
- для каждого существенного вывода указывай `confidence`: `low` | `medium` | `high`;
- findings группируй по категориям:
  - `governance`;
  - `structure`;
  - `decision_quality`;
  - `evidence`;
- внутри каждой категории сортируй по `severity`: `critical` -> `major` -> `minor`;
- не переписывай ADR и не предлагай stylistic rewrites без привязки к конкретной проблеме.

Что проверить:
- соответствует ли ADR актуальному template и governance-документам;
- какие поля frontmatter и обязательные секции `missing`, `extra` или `inconsistent` относительно source of truth;
- согласован ли текст ADR с его `decision_status`;
- достаточно ли ясно описаны проблема, drivers, alternatives, trade-offs, consequences;
- нет ли implementation leakage, который не должен жить в ADR;
- подтверждаются ли ключевые утверждения ссылками или текстом входных артефактов.

Правила приоритизации:
- не размывай ответ мелкими stylistic замечаниями;
- если есть проблемы, делающие ADR непригодным как decision record, ставь их выше локальных недочетов структуры;
- если governance нарушен, явно назови нарушенное правило или источник;
- если evidence не хватает, не маскируй это под обычный editorial comment.

Формат ответа:
- `Review scope`
  - какие артефакты реально были доступны;
- `Findings by category`
  - категории: `governance`, `structure`, `decision_quality`, `evidence`;
  - для каждого finding:
    - `Severity`
    - `Section`
    - `Problem`
    - `Why it matters`
    - `Evidence type`
    - `Evidence`
    - `Confidence`
    - `Suggested fix`
- `Open questions`
- `Missing evidence`
- `Overall verdict`
  - одно из: `ready` | `ready with revisions` | `not ready`

Критерии вердикта:
- `ready`: ADR соответствует source of truth, не содержит blocking issues и пригоден как decision record;
- `ready with revisions`: есть проблемы, но они не ломают саму возможность использовать ADR после ограниченных правок;
- `not ready`: отсутствуют ключевые части ADR, нарушен governance/source of truth, `decision_status` конфликтует с текстом, или аргументация слишком слаба для использования документа.

В конце добавь машинно-читаемый блок:

```json
{
  "step": "review",
  "adr_path": "{ADR_PATH}",
  "state": "ok | blocked | insufficient_context",
  "verdict": "ready | ready with revisions | not ready",
  "blocking_issues": [
    {
      "category": "governance | structure | decision_quality | evidence",
      "summary": "string",
      "evidence_type": "fact | inference | missing",
      "confidence": "low | medium | high"
    }
  ],
  "findings_count": {
    "critical": 0,
    "major": 0,
    "minor": 0
  }
}
```
