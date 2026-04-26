# ADR Prompts Index

Каталог `.prompts/ADR/` хранит pipeline промптов для работы с ADR через AI-агентов.

## Shared Contract

- `Primary artifact`: ADR в файле `{ADR_PATH}`.
- `Allowed sources`: сам ADR, `memory-bank/flows/templates/adr/ADR-XXX.md`, governance-документы из `memory-bank/dna/`, документы из `derived_from` и явно связанные артефакты, если они существуют.
- `Evidence policy`:
  - `fact`: прямо подтверждено входными артефактами;
  - `inference`: логический вывод из подтвержденных фактов;
  - `missing`: информация нужна для вывода, но во входах ее нет.
- `Confidence`: каждый существенный вывод должен иметь `low` | `medium` | `high`.
- `Machine-readable tail`: каждый шаг обязан завершаться коротким JSON-блоком в fenced code block `json`.
- `No fabrication`: нельзя придумывать факты, статусы документов, владельцев, сроки, метрики или downstream-задачи, если они не следуют из входов.
- `Failure handling`: при срабатывании failure mode агент не компенсирует отсутствующий контекст догадками, явно фиксирует blocker в основном ответе и отражает blocked/insufficient-context state в JSON.

## Pipeline

### [`01_review.md`](01_review.md)

Используй, когда нужно провести критичное ревью ADR как документа decision record и сразу оценить силу самого решения.

- `Inputs`:
  - `{ADR_PATH}`;
  - актуальный ADR template;
  - governance/frontmatter docs;
  - `derived_from` и linked docs, если доступны.
- `Output`:
  - findings, сгруппированные по категориям `governance`, `structure`, `decision_quality`, `evidence`;
  - decision summary и evidence matrix по ключевым drivers;
  - recommendation по самому решению;
  - overall verdict;
  - JSON с verdict, recommendation, findings_count, blocking_issues и key_gaps.
- `Preconditions`:
  - ADR-файл существует и читаем;
  - доступен хотя бы template ADR.
- `Can skip when`:
  - есть свежее review того же ADR и с тех пор ADR не менялся.
- `Failure modes`:
  - отсутствует ADR;
  - отсутствует template/governance source of truth;
  - ссылки в ADR ведут на несуществующие документы.
- `Gate to next step`:
  - можно переходить к `02_improve.md`, даже если verdict неидеален, но findings, recommendation и evidence gaps должны быть сохранены как вход.

### [`02_improve.md`](02_improve.md)

Используй, когда нужно исправить ADR по findings review, не превращая это в произвольный rewrite.

- `Inputs`:
  - текущий ADR;
  - findings, recommendation и evidence gaps из review;
  - дополнительные факты от автора, если они явно переданы.
- `Output`:
  - обновленный текст ADR;
  - change notes;
  - author input required;
  - JSON с edit_mode, unresolved_items и placeholder_policy.
- `Preconditions`:
  - есть конкретные findings или decision gaps, которые нужно исправить.
- `Can skip when`:
  - review не выявил изменений, требующих правок ADR.
- `Failure modes`:
  - входные замечания противоречат друг другу;
  - для обязательных секций не хватает фактов;
  - requested state = `accepted`, но данные неполны и placeholder недопустим.
- `Gate to next step`:
  - `03_apply.md` запускается только на ADR, который либо не содержит unresolved placeholders, либо явно остается в draft/proposed.

### [`03_apply.md`](03_apply.md)

Используй, когда нужно определить, какие подтвержденные downstream-изменения следуют из ADR.

- `Inputs`:
  - актуальный ADR после шага improve или ручных правок;
  - связанные документы, явно упомянутые в ADR.
- `Output`:
  - impact summary;
  - explicit follow-ups;
  - inferred suggestions;
  - blockers;
  - JSON с state, required_updates и inferred_updates.
- `Preconditions`:
  - ADR достаточно стабилен для downstream-анализа;
  - в ADR есть ссылки или формулировки, из которых следуют последствия.
- `Can skip when`:
  - ADR отклонен (`rejected`) или superseded без требований к downstream.
- `Failure modes`:
  - ADR слишком абстрактен и не ссылается на конкретные артефакты;
  - implied changes неотличимы от догадок;
  - связанный контекст отсутствует.
- `Gate to complete`:
  - required updates перечислены и отделены от inferred suggestions;
  - blockers явно зафиксированы.

## Recommended Order

1. `01_review.md`
2. `02_improve.md`
3. `03_apply.md`
