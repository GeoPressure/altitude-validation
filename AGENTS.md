# Manuscript and supplementary writing

Write manuscript and supplementary material for a reader encountering the study for the first time.

- Describe the current study design, methods and findings directly and make the text self-contained.
- Do not explain earlier drafts, previous datasets, abandoned methods, corrections, or changes made during our conversations unless the user explicitly requests that history.
- Do not add statements merely to negate a previous implementation or exception. For example, if the method selects one station per grid cell, state that rule without adding that no extra stations are selected by elevation.
- Include comparisons, exclusions and limitations when they are scientifically necessary to understand the current study, not because they address an earlier iteration.
- Keep revision rationale, implementation history and author-facing decisions in separate review notes, outside text intended for publication.
- Omit implementation bookkeeping and generic assurances about recording, logging, saving or reproducibility unless they explain a scientifically relevant method or identify an actual data/code resource the reader needs. Every sentence should help the reader understand the study, reproduce a substantive method, or interpret its findings.
- When revising a section, rewrite it around the final method or argument rather than accumulating explanations of individual corrections.
- Write methods and supplementary processes in complete, readable sentences. Use parallel headings and sentence structure for related datasets, explaining what each operation achieves.
- Keep scientific selection criteria and material assumptions in the text; leave seed numbers, raw missing-value codes and detailed parsing conventions to the code unless they are needed to interpret the study.

# Scientific workflow scope

- Keep requested quality criteria in the main accept/reject process. Do not replace an exclusion rule with diagnostic tagging, a separate flagged dataset or a secondary sensitivity analysis unless the user requests that change.
- Prefer one clear selection path. Do not introduce parallel samples, extra processing stages or additional diagnostic outputs without a specific scientific need agreed with the user.
- Retain necessary scientific rejection criteria and requested sampling counts; avoid generic record-keeping systems or metadata layers around them.
