Улучши ADR в файле `{ADR_PATH}` по результатам review, сохранив intent автора и формат project documentation.

Входные данные:
- текущий текст ADR;
- findings, recommendation и evidence gaps из review;
- дополнительные факты от автора, если они явно переданы.

Цель:
- сделать ADR более ясным, полным и пригодным к принятию без изменения сути решения, если это не запрошено явно.

Операционный контракт:
- сохраняй существующий текст, если он корректен;
- меняй только проблемные участки;
- не делай stylistic rewrites без причины;
- не меняй архитектурное направление, если входные данные не требуют этого явно;
- исправляй frontmatter, структуру, аргументацию и cross-references только там, где есть подтвержденная проблема;
- если замечание нельзя закрыть без новых фактов, не выдумывай текст.

Placeholder policy:
- если `decision_status` = `accepted`, placeholders и TODO в итоговом ADR запрещены;
- если ADR остается в `proposed` или `draft`, можно использовать явную метку `[UNRESOLVED]`, но только там, где без нее нельзя честно сохранить документ;
- все unresolved points должны быть отдельно перечислены в `Author input required`.

Если входные данные конфликтуют:
- следуй подтвержденным фактам из ADR и связанных документов;
- явно обозначай unresolved gap вместо произвольного выбора одной из версий.

Формат ответа:
- `Edit strategy`
  - какие sections менялись и почему;
- `Updated ADR`
  - верни полный обновленный текст ADR целиком, но сохрани неизменные части максимально близко к исходнику;
- `Change notes`
  - кратко перечисли, что было исправлено;
- `Author input required`
  - какие данные все еще нужны;

В конце добавь машинно-читаемый блок:

Фактическое значение `used_placeholders` должно быть boolean: `true`, если в итоговом ADR действительно остались placeholders, иначе `false`.

```json
{
  "step": "improve",
  "adr_path": "{ADR_PATH}",
  "state": "ok | blocked | insufficient_context",
  "edit_mode": "targeted",
  "used_placeholders": true,
  "placeholder_policy": "accepted_forbidden | proposed_allowed",
  "unresolved_items": [
    "string"
  ]
}
```
