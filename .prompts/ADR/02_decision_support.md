Выступи как decision support агент для ADR в файле `{ADR_PATH}`.

Твоя задача: оценить не качество оформления, а качество самого решения и силу подтверждающего evidence.

Используй только:
- сам ADR;
- `memory-bank/flows/templates/adr/ADR-XXX.md`;
- findings из review, если они переданы;
- документы из `derived_from` и связанных ссылок, если они существуют;
- явно указанные в ADR ограничения, assumptions и non-goals.

Операционный контракт:
- отделяй `fact`, `inference` и `missing`;
- для каждого существенного вывода указывай `confidence`: `low` | `medium` | `high`;
- оценивай решение через evidence matrix по ключевым decision drivers;
- recommendation должна выводиться из matrix и критериев ниже, а не из общего впечатления.
- если drivers не выделены явно, сначала перечисли `reconstructed drivers` с пометкой `inference`;
- если drivers невозможно реконструировать без домыслов, не поднимай recommendation выше `request more evidence`.

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

Правила:
- не оценивай документ только по форме;
- не придумывай внешние факты;
- не делай вид, что evidence есть, если его нет;
- если вывод зависит от предположения, явно пометь это как `inference`.

Формат ответа:
- `Decision summary`
  - в чем решение и какие drivers заявлены;
- `Evidence matrix`
  - таблица по всем ключевым drivers;
- `Support for the proposed decision`
- `Challenges and doubts`
- `Alternative paths worth serious consideration`
- `Evidence still needed before approval`
- `Recommendation`
  - одно из: `accept` | `accept with conditions` | `request more evidence` | `revise decision` | `reject`
- `Why`
  - короткое объяснение, как recommendation вытекает из evidence matrix;
- `Decision meeting checklist`
  - 3-7 вопросов, которые команда должна закрыть до принятия.

В конце добавь машинно-читаемый блок:

```json
{
  "step": "decision_support",
  "adr_path": "{ADR_PATH}",
  "state": "ok | blocked | insufficient_context",
  "recommendation": "accept | accept with conditions | request more evidence | revise decision | reject",
  "confidence": "low | medium | high",
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
