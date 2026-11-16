# Tasks: MQTT Antena specification baseline

- [x] **1. Draft the functional specification** (`specs/functional_specs.md`)
  - Use all configured functional section titles in their configured order.
  - Describe current user-visible behavior, rules, workflows, covered errors, and observable acceptance criteria.
  - Include the companion-project links as context only; label unresolved and malformed-input behavior accurately.
  - **Verification:** reviewed against `src/app.py`, `src/database.py`, `src/mqtt_manager.py`, relevant templates, and README. Configured section titles are present and ordered.
  - **Completion criteria:** each required functional section is present; claims are traceable to repository behavior/docs; no unapproved future behavior is stated as a requirement.

- [x] **2. Draft the technical specification** (`specs/technical_specs.md`)
  - Use all configured technical section titles in their configured order.
  - Describe architecture, dependencies, interfaces, data/persistence, access controls, operations, tests, and current constraints.
  - Record security and validation concerns as observations/ToDos, not as claims of protection or as prescribed remediation.
  - **Verification:** reviewed against source/models, `requirements*.txt`, Docker files, tests, GitHub Actions workflows, and README. Configured section titles are present and ordered.
  - **Completion criteria:** each required technical section is present; deployment and CI details match repository configuration; companion-project internals are not asserted.

- [x] **3. Review consistency and evidence across both specifications**
  - Cross-check functional statements against routes, templates, models, and MQTT callbacks; cross-check technical statements against dependency, Docker, CI, and release configuration.
  - Check key shared facts (ownership, connection lifecycle, subscription behavior, message delivery, and persistence) for consistency between the documents.
  - Verify section titles/order against `.simple-spec/config.yaml` and ensure unresolved items remain clearly labeled.
  - **Verification:** checked shared ownership, connection, subscription, message-delivery, persistence, and companion-project statements against source/docs. Ran a Python heading-order check and whitespace/final-newline check; both passed. `git diff --check` produced no whitespace errors for tracked changes. Archive test run: `make test` — 12 passed, 1 skipped, with 2 deprecation warnings.
  - **Completion criteria:** no material contradictions or unsupported claims remain; both documents describe the same current-state boundaries and preserve the documented ToDos.
