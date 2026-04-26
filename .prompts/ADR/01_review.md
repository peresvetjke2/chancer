Проведи критичное ревью ADR в файле `{ADR_PATH}` как decision record и одновременно оцени силу самого решения.

Используй только:
- сам ADR;
- `memory-bank/flows/templates/adr/ADR-XXX.md`;
- `memory-bank/dna/governance.md`;
- `memory-bank/dna/frontmatter.md`;
- `memory-bank/adr/README.md`;
- findings из предыдущего review, если они явно переданы как вход для повторного прогона;
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
- оценивай решение через evidence matrix по ключевым decision drivers;
- recommendation должна выводиться из evidence matrix, а не из общего впечатления;
- если drivers не выделены явно, сначала перечисли `reconstructed drivers` с пометкой `inference`;
- если drivers невозможно реконструировать без домыслов, не поднимай recommendation выше `request more evidence`;
- не переписывай ADR и не предлагай stylistic rewrites без привязки к конкретной проблеме.

Что проверить:
- соответствует ли ADR актуальному template и governance-документам;
- какие поля frontmatter и обязательные секции `missing`, `extra` или `inconsistent` относительно source of truth;
- согласован ли текст ADR с его `decision_status`;
- достаточно ли ясно описаны проблема, drivers, alternatives, trade-offs, consequences;
- нет ли implementation leakage, который не должен жить в ADR;
- подтверждаются ли ключевые утверждения ссылками или текстом входных артефактов.
- покрыты ли ключевые decision drivers достаточным evidence;
- выдерживает ли proposed decision сравнение с alternatives и собственными constraints;
- какие assumptions или evidence gaps блокируют уверенное принятие решения.

Правила приоритизации:
- не размывай ответ мелкими stylistic замечаниями;
- если есть проблемы, делающие ADR непригодным как decision record, ставь их выше локальных недочетов структуры;
- если governance нарушен, явно назови нарушенное правило или источник;
- если evidence не хватает, не маскируй это под обычный editorial comment.

Построй evidence matrix в формате:
- `Driver`
- `Why it matters`
- `Evidence present`
- `Evidence type`: `fact` | `inference` | `missing`
- `Confidence`: `low` | `medium` | `high`
- `Risk if wrong`: `low` | `medium` | `high`
- `Gap to close`

Статусы рекомендации и критерии выбора:
- `accept`
  - ключевые drivers покрыты достаточным evidence;
  - серьезных unresolved gaps нет;
  - remaining risks допустимы как consequence выбранного решения.
- `accept with conditions`
  - решение в целом выдерживает сравнение с альтернативами;
  - есть bounded follow-ups или проверки, не меняющие ядро решения.
- `request more evidence`
  - хотя бы один ключевой driver опирается на слабый или отсутствующий evidence;
  - решение может быть разумным, но его пока нельзя уверенно принять.
- `revise decision`
  - текущий вариант не выдерживает сравнения с альтернативами;
  - недооценены trade-offs или assumptions слишком сильны;
  - нужно менять само направление решения, а не только усиливать доказательную базу.
- `reject`
  - решение противоречит входным ограничениям, canonical context или собственным drivers настолько, что не должно продвигаться дальше в текущем виде.

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
- `Decision summary`
  - в чем решение и какие drivers заявлены или реконструированы;
- `Evidence matrix`
  - таблица по всем ключевым drivers;
- `Support for the proposed decision`
- `Challenges and doubts`
- `Alternative paths worth serious consideration`
- `Open questions`
- `Missing evidence`
- `Recommendation`
  - одно из: `accept` | `accept with conditions` | `request more evidence` | `revise decision` | `reject`
- `Why`
  - короткое объяснение, как recommendation вытекает из evidence matrix;
- `Decision meeting checklist`
  - 3-7 вопросов, которые команда должна закрыть до принятия;
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
  "recommendation": "accept | accept with conditions | request more evidence | revise decision | reject",
  "confidence": "low | medium | high",
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
  },
  "key_gaps": [
    {
      "driver": "string",
      "gap": "string",
      "risk_if_wrong": "low | medium | high",
      "evidence_type": "fact | inference | missing",
      "confidence": "low | medium | high"
    }
  ]
}
```
