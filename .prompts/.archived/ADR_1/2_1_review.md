Проведи критичное ревью ADR в файле `{ADR_PATH}` по шаблону `memory-bank/flows/templates/adr/ADR-XXX.md`.

Используй только:
- сам ADR;
- шаблон ADR;
- `memory-bank/dna/governance.md`;
- `memory-bank/dna/frontmatter.md`;
- `memory-bank/adr/README.md`;
- документы из `derived_from` и `Связанных ссылок`, если они реально существуют.

Проверь:
- соответствие шаблону и наличие обязательных секций;
- корректность frontmatter: `title`, `doc_kind`, `doc_function`, `purpose`, `derived_from`, `status`, `decision_status`, `date`, `audience`;
- согласованность текста с `decision_status`:
  - при `proposed` не должно быть языка уже принятого решения;
  - при `accepted` решение должно быть явно зафиксировано как принятое;
- качество аргументации: ясность проблемы, драйверов, альтернатив, trade-offs и причин выбора;
- полноту последствий, рисков, mitigation и follow-up;
- корректность связей с другими документами и соблюдение SSoT/governance;
- отсутствие неуместных `implementation plan` и `current system state`.

Правила:
- будь критичным и конкретным;
- не переписывай ADR целиком;
- не придумывай факты, документы или намерения автора;
- каждое замечание подтверждай явным evidence: цитатой, ссылкой на секцию или указанием, что обязательный элемент отсутствует;
- если проблема связана с governance, явно назови нарушенное правило.

Формат ответа:
- сначала `Findings` по убыванию критичности;
- для каждого:
  - `Severity`: `critical` | `major` | `minor`
  - `Section`
  - `Problem`
  - `Why it matters`
  - `Evidence`
  - `Suggested fix`
- затем `Open questions`
- затем `Missing evidence`
- затем `Overall verdict`: `ready` | `ready with revisions` | `not ready`

Критерии вердикта:
- `ready`: нет проблем, мешающих использовать ADR как decision record;
- `ready with revisions`: есть исправимые проблемы, но ADR в целом состоятельный;
- `not ready`: отсутствуют ключевые секции, нарушен frontmatter/governance, `decision_status` противоречит тексту, или аргументация не позволяет принять решение.