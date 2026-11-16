# Technical Specifications — MQTT Antena

> This document records the technical design and operational behavior visible in this repository. It is a current-state baseline, not a declaration that existing security properties or operational limits meet a particular policy. **ToDo** items are open questions or risks, not implemented controls.

## Architecture and Components

### Application structure

- `src/app.py` creates the Flask application, configures Flask-SocketIO with gevent, registers HTTP routes and Socket.IO handlers, initializes the database, and exposes the Flask application as `app`.
- `src/database.py` defines the SQLAlchemy `User` and `Broker` models and password hash/check methods.
- `src/mqtt_manager.py` wraps Paho MQTT clients, manages subscriptions and connection callbacks, and broadcasts received messages through Socket.IO.
- `src/templates/` contains server-rendered Jinja pages. `src/static/` contains stylesheet and image assets. Browser JavaScript handles the theme toggle, Socket.IO message stream, and subscription form state.
- `IngressMiddleware` maps the `X-Ingress-Path` request header to WSGI `SCRIPT_NAME` for Home Assistant Ingress path routing.

### Runtime flow

1. Flask routes read/write users and broker configuration through Flask-SQLAlchemy.
2. A connect request creates an `ActiveClient` and starts Paho's asynchronous connection loop.
3. On MQTT connection success, the runtime client's connection flag is updated; on MQTT messages, the callback forms a message record and emits `mqtt_message` to `user_<user_id>` through Flask-SocketIO.
4. The browser's Socket.IO connection joins the authenticated user's room and renders received messages in the subscription view.
5. Publish requests use the selected runtime client to invoke Paho's publish call.

Active MQTT clients are stored in the process-local `connected_clients` dictionary keyed by broker ID. Connection state and subscription state are not shared across processes and are not persisted in the database.

## Technology Stack and Dependencies

- Runtime: Python 3.11-based Docker image; the CI workflow currently configures Python 3.11.14.
- Web application: Flask 3.1.2 and Flask-SQLAlchemy 3.1.1.
- MQTT: Paho MQTT 2.1.0.
- WebSocket/event transport: Flask-SocketIO 5.6.0, python-socketio 5.16.0, and simple-websocket 1.1.0.
- Concurrency and serving: gevent 25.9.1; Gunicorn 23.0.0.
- Persistence: SQLite through SQLAlchemy.
- Development/test tools: Ruff, pytest 8.3.4, pytest-mock 3.14.0, and pytest-flask 1.3.0.
- The browser subscription page loads a Socket.IO JavaScript client from a CDN.

The application dependencies are pinned in `requirements.txt`; development dependencies are listed in `requirements-dev.txt`.

## Interfaces and Contracts

### HTTP interface

The application exposes server-rendered Flask routes. The primary routes are:

| Route | Methods | Access and behavior |
| --- | --- | --- |
| `/` | GET | Redirects to broker management when a session is present, otherwise to login. |
| `/register` | GET, POST | Public registration form and account creation. Successful registration logs the new user in. |
| `/login` | GET, POST | Public login form and session creation. |
| `/logout` | GET | Removes the session's `user_id` and redirects to login. |
| `/howto` | GET | Public how-to page. |
| `/brokers` | GET, POST | Login-protected broker listing and add/connect/disconnect/delete actions. |
| `/brokers/edit/<broker_id>` | GET, POST | Login-protected edit of a broker owned by the current user. |
| `/subscription` | GET | Login-protected subscription controls and current active brokers. |
| `/toggle_listen` | POST | Login-protected start/stop subscription action. |
| `/publish` | GET, POST | Login-protected publish form and publish action. |

The login-required decorator checks for `user_id` in the Flask session. Broker edit/delete lookups are scoped to that user. The subscription and publish handlers also check ownership when a runtime client is found and connected, respectively. Forms submit as regular HTTP requests and communicate user feedback through Flask flash messages and redirects.

The Flask CLI command is `reset-password`, with positional username and password arguments. It updates the user's password hash or reports that the username was not found.

### Socket.IO interface

- The configured async mode is gevent; the Socket.IO CORS setting is `*`.
- A Socket.IO connection is rejected unless its Flask session contains `user_id`. Accepted connections join room `user_<user_id>`.
- The server emits event `mqtt_message` to that user room. The event object contains `broker_id`, `broker_name`, `timestamp`, `topic`, and `payload`.
- `timestamp` is produced by the server in `%H:%M:%S` format. MQTT payloads are decoded as text when possible; undecodable bytes are represented using Python's string conversion.
- The browser subscription page listens for `mqtt_message` and appends it to the on-page message display. The UI label “SSE Status” is stale terminology; the actual implementation uses Socket.IO.

### MQTT interface

- The user supplies broker host/IP, port, and optional username/password. The add form defaults the port to `1883`.
- Paho connections are initiated with `connect_async` using a 60-second keepalive and the network loop is started in the background. The route's immediate result indicates that initiation succeeded, not that the broker connection was accepted.
- MQTT credentials are configured only when both username and password are present.
- The runtime client tracks subscriptions. Updating a subscription unsubscribes its tracked topics first; an empty topic is converted to `#`. Stopping clears the tracked subscriptions.
- Publish calls pass the selected topic, payload, QoS, and retain flag to Paho.
- The repository does not configure TLS or certificate options for MQTT connections.

### Companion project boundaries

The README links the separate [Home Assistant add-on](https://github.com/fbossolan/mqtt-antena-hass-addon) and [MQTT Antena Mobile App](https://github.com/fbossolan/mqtt-antena-mobile), described there as a work in progress. This repository's documented interface to the add-on includes Ingress path handling and data-directory support; no mobile-app protocol or integration contract is defined in this repository. The companion repositories are not specified here.

## Data and Persistence

### Entities

- `User`: integer primary key, unique non-null username (maximum 80 characters), and non-null password hash (maximum 200 characters).
- `Broker`: integer primary key, required foreign key to `User`, non-null name (maximum 100), host/IP (maximum 100), integer port (default 1883), and nullable MQTT username/password (maximum 100 each).
- Each broker has a SQLAlchemy relationship to its owning user.

### Database and persistence behavior

- The database is SQLite at `antena.db` in the selected data directory. If `/data` exists, the application uses it; otherwise, it uses the repository-root `data` directory. The directory is created if needed.
- SQLAlchemy `create_all()` is called during application initialization. No schema migration framework is configured in the reviewed repository.
- User accounts and broker configurations persist in SQLite.
- Broker connection status, active MQTT clients, and subscriptions are held in memory only. They start disconnected/not restored after an application restart.
- Incoming MQTT message history is not stored. The browser display is transient and is cleared on page refresh or when the user clears it.
- `Broker.to_dict()` includes broker credentials in its returned dictionary; no separate secret-storage mechanism is implemented in the model.

## Security and Permissions

### Implemented behavior

- User passwords are handled through Werkzeug password hashing and verification; plaintext account passwords are not stored as the `User` password field.
- Flask session state is used to identify the logged-in user. Protected routes check for a session `user_id`.
- Broker management lists and edit/delete operations scope records by owner. The Socket.IO connection is gated on an authenticated session and emits messages to a per-user room.

## Performance and Operations

### Deployment

- The Dockerfile uses a multi-stage Python 3.11 slim image, installs the pinned application dependencies, exposes port `8585`, and starts Gunicorn with the gevent worker class, one worker, and bind address `0.0.0.0:8585`.
- Running `src/app.py` directly starts Socket.IO on `0.0.0.0:8585` with Flask debug mode enabled; the documented container entry point uses Gunicorn.
- Docker Compose maps host port `8585` to container port `8585` and mounts local `./data` at `/app/data`.
- The README documents standalone Docker usage and Home Assistant add-on use. The application chooses `/data` when present, otherwise its project-relative `data` directory.
- Ingress path support is provided through the `X-Ingress-Path` header middleware.
- The tagged release workflow builds and pushes images for `linux/amd64`, `linux/arm64`, `linux/arm/v7`, and `linux/arm/v6`.

### Runtime constraints and observability

- Gevent monkey-patching occurs before the other application imports so Paho's socket operations cooperate with the gevent runtime.
- One Gunicorn worker is configured. MQTT client state is process-local; multi-worker coordination or external shared connection state is not implemented.
- MQTT connect is asynchronous. Status is updated through Paho callbacks; connection state is not durable.
- The application logs connection, disconnection, subscription, and received-message information to standard output. No separate metrics or structured observability system is configured in this repository.
- No formal capacity, throughput, latency, or availability targets are specified.

## Testing Strategy

- Tests use pytest and are located in `tests/`.
- Route tests cover login redirects, registration/login/logout, password mismatch, login protection, broker creation, a user-isolation case, publishing with QoS/retain, and Home Assistant Ingress redirect behavior.
- Model tests cover password hashing/checking and broker dictionary serialization.
- MQTT integration tests exercise connection, subscription, publishing, and Socket.IO message broadcasting against a temporary Mosquitto container. The fixture uses Docker and skips if the Docker command returns a nonzero exit status while starting the broker; an unavailable Docker executable may fail before that skip handler. The tests also cover asynchronous connection initiation to an unreachable address.
- GitHub Actions CI runs Ruff (`ruff check src`) and `pytest tests/` on pushes and pull requests targeting `main`. The tagged release workflow repeats those checks before building/pushing the image.
- This specification records the existing strategy; it does not claim tests were executed as part of this documentation change.

## Technical Decisions and Constraints

- Flask/Jinja server-rendered pages are combined with client-side JavaScript and Socket.IO for live message display.
- SQLite persists accounts and broker configurations; no persistent MQTT connection manager or message-history store is implemented.
- Paho MQTT clients are maintained in a process-local dictionary and are created on demand. They are not reconnected automatically after application restart.
- Gevent is used for Socket.IO and Gunicorn serving; one Gunicorn worker is configured to align with in-process MQTT state.
- The app's database tables are created with SQLAlchemy `create_all()` at initialization; no migration process is present in the repository.
- The README and current implementation differ in some terminology: for example, the subscription UI displays “SSE Status” while the transport is Socket.IO. The implementation is the source for actual current transport behavior; such discrepancies should remain visible as documentation/UI ToDos.
- No TLS, scale-out, durable message retention, or specific security/compliance target is specified by this baseline. Any such target requires a separate confirmed decision.
