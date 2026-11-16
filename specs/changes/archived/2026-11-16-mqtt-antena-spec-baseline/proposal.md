# Proposal: MQTT Antena functional and technical specification baseline

## Summary

Create the first substantive functional and technical specifications for MQTT Antena. The configured spec files are currently empty. The specifications will describe the current, observable behavior of this repository as a self-hosted web MQTT client, using the README for product context and the implementation as the source of truth for behavior.

This is a documentation-only change. It will record current limitations and risks as explicit ToDos or implementation observations, rather than silently presenting proposed improvements as existing behavior or approved requirements.

## Goals and scope

### Goals

- Establish a clear functional baseline for users, authentication, broker management, MQTT subscriptions and message viewing, publishing, persistence, validation, and error handling.
- Establish a technical baseline for the application architecture, dependencies, web and MQTT interfaces, data, security boundaries, deployment, operations, and testing.
- Make the boundary between implemented behavior, project-documentation claims, and unresolved ToDos clear.
- Identify the linked Home Assistant add-on and MQTT Antena Mobile App as companion projects, without asserting that their implementation or integration behavior is part of this repository.

### In scope

- Populate the configured permanent documents: `specs/functional_specs.md` and `specs/technical_specs.md`.
- Describe behavior supported by the current code and relevant repository documentation.
- Note important discrepancies, limitations, and unresolved policies as ToDos or clearly labeled observations.

### Out of scope

- Changing application code, tests, deployment configuration, or companion projects.
- Adding new or aspirational product behavior, including prescribing security or validation fixes.
- Specifying the internals of the companion Home Assistant add-on or mobile app; only their README links and related-project status are in scope.

## Functional specification

The functional specification will follow the configured section order and titles:

1. **Purpose and Scope** — Describe MQTT Antena as a self-hosted web MQTT client for development/analysis, identify its users and boundaries, and mention the separately linked Home Assistant add-on and mobile app as companion projects.
2. **Functional Capabilities** — Document registration/login/logout and CLI password reset; user-owned broker configuration and connection controls; topic subscription and live message display; message publishing with QoS and retain; and the UI's documented theme behavior where applicable.
3. **Business Rules** — Record observable rules such as broker records being user-scoped, an empty subscription topic mapping to `#`, subscription updates replacing the client's previous topic, runtime-only connection/subscription state, and non-persistence of message history.
4. **User and System Interactions** — Describe the principal registration/login, broker management, connect/disconnect, subscribe/stop, and publish workflows, including the live message flow from MQTT through Socket.IO to the browser.
5. **Validation and Error Handling** — Describe implemented feedback for authentication, duplicate registration, connection failures, missing broker selection, and publishing while disconnected. Call out direct conversions and insufficiently specified malformed-input behavior as current limitations/ToDos rather than inventing validation rules.
6. **Acceptance Criteria** — Provide observable checks aligned with the documented current baseline, including ownership isolation, message streaming, publish options, persistence boundaries, and user feedback for covered errors.

## Technical specification

The technical specification will follow its configured section order and titles:

1. **Architecture and Components** — Describe Flask routes/templates, SQLAlchemy models, MQTT client manager, Socket.IO event handling, gevent, and the in-process active-client registry.
2. **Technology Stack and Dependencies** — Record the Python runtime/build context and pinned application dependencies, plus pytest/Ruff development tooling.
3. **Interfaces and Contracts** — Document the server-rendered web workflows, forms/routes, Socket.IO authentication and `mqtt_message` event payload, MQTT connection/subscription/publish behavior, and Home Assistant Ingress path handling.
4. **Data and Persistence** — Describe User and Broker records, SQLite database location selection, stored versus runtime-only data, and the fact that message history and connection state are not persisted.
5. **Security and Permissions** — State implemented session and ownership checks, password hashing, and credential handling. Explicitly flag public registration, broker credential storage, the development secret fallback, wildcard Socket.IO CORS, and browser message rendering as observed security ToDos—not security guarantees or approved fixes.
6. **Performance and Operations** — Document Docker and Home Assistant add-on context, `/data` and local data-directory behavior, Gunicorn/gevent deployment with one worker, asynchronous broker connection attempts, ingress support, and release image build targets. Avoid adding unsupported capacity or latency targets.
7. **Testing Strategy** — Describe the pytest/Ruff CI checks and the Docker-backed Mosquitto integration test, including that the MQTT integration fixture can skip when Docker is unavailable.
8. **Technical Decisions and Constraints** — Record SQLite, process-local connection state, single-worker deployment, live-only message handling, and implementation/documentation discrepancies as current constraints or ToDos.

## Error handling and edge cases

- Broker connection initiation is asynchronous: a successful call to initiate a connection is not the same as a confirmed broker connection; the later MQTT callback updates runtime status.
- A broker's current subscription is cleared when it is replaced; an empty topic means `#`.
- Only connected brokers are offered for subscription and publishing. Publishing to an unavailable/disconnected client produces user feedback rather than sending a message.
- Runtime connections and browser message output are lost on server restart or page refresh respectively; saved accounts and broker configurations remain in SQLite.
- Several malformed form values may raise conversion or downstream errors. The specifications will identify this as an implementation gap rather than promise graceful validation.
- The subscription UI retains an “SSE Status” label although the implementation uses Socket.IO; document the actual transport and flag the label mismatch.

## Testing and verification strategy

- Cross-check every functional statement against the relevant route, template, model, or MQTT callback; cross-check deployment and test statements against repository configuration and CI files.
- Verify that the documented section names and order match `.simple-spec/config.yaml` and that all required configured sections are present.
- Review acceptance criteria for observable, current-state behavior and ensure no proposed fix or unverified companion-project behavior is stated as implemented.
- No application test execution is required for this documentation-only change. Do not claim code behavior has been newly tested as part of writing the documents.

## Risks, constraints, assumptions, and unresolved decisions

- **Confirmed scope:** current behavior only; no future requirements are to be inferred.
- **Confirmed companion-project scope:** mention the linked add-on and mobile app as related projects; do not inspect or specify their internals in this change.
- **Assumption:** repository code is authoritative for current behavior; README and other docs provide product context but may be stale.
- **ToDos, not blockers:** confirm whether public registration is intended for all deployments; whether there is an admin/first-user policy; intended TLS/MQTT security support; whether a separate security/operations policy exists; and which implementation limitations merit future work.
- **Constraint:** the permanent specifications are documentation, not a promise that current behavior is safe, desirable, or complete.
