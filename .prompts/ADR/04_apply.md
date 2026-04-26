Выступи как apply-агент после обновления или принятия ADR в файле `{ADR_PATH}`.

Твоя задача: определить, какие downstream-изменения подтвержденно следуют из ADR, а что является лишь полезной гипотезой.

Используй только:
- сам ADR;
- связанные документы из `derived_from`;
- ссылки на PRD, feature packages, runbooks, config docs и другие явно упомянутые артефакты, если они существуют.

Операционный контракт:
- отделяй `Explicitly implied by ADR` от `Inferred suggestions`;
- для каждого follow-up указывай `confidence`: `low` | `medium` | `high`;
- не придумывай owners, deadlines, rollout gates или implementation tasks, если они не подтверждены;
- если owner/deadline не указаны в ADR, пиши, где они должны быть назначены, а не назначай их сам;
- если изменение не следует из текста ADR или связанных документов, не помещай его в обязательные действия.

Проверь:
- какие документы явно становятся stale после принятия или изменения ADR;
- какие sections в memory-bank надо обновить по прямой связи;
- какие implementation follow-ups явно следуют из решения;
- какие проверки, миграции или rollout steps прямо требуются;
- какие выводы остаются лишь inference и не должны трактоваться как обязательный plan.

Формат ответа:
- `Impact summary`
- `Explicitly implied by ADR`
  - для каждого item:
    - `Artifact`
    - `Required change`
    - `Evidence type`
    - `Evidence`
    - `Confidence`
- `Inferred suggestions`
  - только как гипотезы, не как обязательства;
- `Validation and rollout`
  - только подтвержденные проверки и gates, плюс отдельно inference;
- `Open blockers`
- `Execution order`
  - только для подтвержденных обязательных шагов;
- `Done definition`
  - как понять, что ADR действительно применен.

В конце добавь машинно-читаемый блок:

```json
{
  "step": "apply",
  "adr_path": "{ADR_PATH}",
  "state": "ok | blocked | insufficient_context",
  "required_updates": [
    {
      "artifact": "string",
      "change": "string",
      "evidence_type": "fact | inference | missing",
      "confidence": "low | medium | high"
    }
  ],
  "inferred_updates": [
    {
      "artifact": "string",
      "change": "string",
      "evidence_type": "fact | inference | missing",
      "confidence": "low | medium | high"
    }
  ]
}
```
