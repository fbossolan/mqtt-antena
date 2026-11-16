# Functional Specifications — MQTT Antena

> This document describes the current, observable behavior of the application in this repository. It is a baseline, not a commitment that every current behavior is desirable or complete. Items marked **ToDo** are unresolved policy or improvement questions, not implemented requirements.

## Purpose and Scope

MQTT Antena is a self-hosted, browser-based MQTT client intended as a development and analysis tool for MQTT-based applications and IoT systems. It lets users save MQTT broker connection details, connect to brokers, observe live messages for a topic, and publish messages.

The application in this repository is a Flask web application that can run as a standalone Docker container and is also used in a Home Assistant add-on context. The README links two separate companion projects:

- [MQTT Antena Home Assistant add-on](https://github.com/fbossolan/mqtt-antena-hass-addon)
- [MQTT Antena Mobile App](https://github.com/fbossolan/mqtt-antena-mobile)

These links identify related projects only. Their behavior and integration details are outside the scope of this specification.

The current application includes user registration and session-based login, per-user broker configuration, broker connection management, MQTT topic subscription and live message viewing, and MQTT message publishing. It does not provide persisted message history, persistent connection status, or in-app password recovery.

## Functional Capabilities

### Accounts and access

- A visitor can register with a username, password, and password confirmation. A successful registration creates the account, starts a logged-in session, and redirects to broker management.
- A username already present in the database is rejected with a user-visible error. A password/confirmation mismatch is also rejected with a user-visible error.
- A registered user can log in with the matching username and password and log out.
- A user can reset an account password through the `flask reset-password <USERNAME> <PASSWORD>` command. There is no in-app password-reset flow.
- Pages and operations marked as login-protected redirect unauthenticated requests to the login page. The `/howto` guide is publicly accessible.

### Broker management

- An authenticated user can add, view, edit, connect to, disconnect from, and delete their broker configurations.
- A broker configuration contains a display name, host/IP, port, and optional MQTT username and password. The add form defaults the port to `1883`; if no name is supplied, the host/IP is used as the name.
- Broker records are listed and operated on in the context of their owning user. A user does not see another user's broker records in their broker list.
- The broker list displays runtime status as connected, disconnected, or error when an error is available. A connection attempt starts asynchronously; the initial request does not itself confirm that the broker accepted the connection.
- Editing a broker updates the stored connection details and removes the current runtime client so the changed configuration can be used on a subsequent connection attempt.
- Deleting a broker removes its runtime client if present and deletes its stored configuration.

### Topic subscriptions and live message viewing

- An authenticated user can select one of their connected brokers and start listening on a topic.
- An empty topic is treated as the MQTT wildcard topic `#`.
- Starting a new topic subscription on a broker removes the client's prior subscriptions before subscribing to the new topic. The UI presents the current subscription for each connected broker.
- Incoming MQTT messages are sent to the user's active Socket.IO sessions and displayed in the browser. Displayed message information includes broker name, topic, payload, and a server-generated time string.
- The browser's **Clear Messages** action clears the current page's displayed messages. It does not alter the MQTT broker or persist/delete any server-side history.

### Message publishing

- An authenticated user can publish a message through one of their connected brokers.
- A publish operation supplies a topic and message payload, supports QoS `0`, `1`, or `2`, and supports the MQTT retain flag.
- The publish page offers connected brokers. A request made when the selected broker client is not connected produces a user-visible “Broker not connected” error.

### User interface

- The application uses server-rendered pages for login, registration, broker management, subscription, publishing, and a how-to guide.
- The common layout includes a light/dark theme toggle. The selected theme is stored in browser `localStorage`; the default is light.
- The subscription page uses Socket.IO for live updates. Its current status caption says “SSE Status”; this is a UI label mismatch, not the transport in use.

## Business Rules

- Each broker record belongs to one user, and broker list operations are scoped to the authenticated user.
- The username is unique in the database. Passwords are stored as password hashes rather than plaintext.
- Broker name is optional in the add/edit UI; the host/IP is used as the name when the name is empty.
- The add-broker form defaults to port `1883`. The application stores the submitted broker port as an integer.
- A broker's connection state and active MQTT client are runtime-only. Users must reconnect after an application restart.
- A new subscription replaces the subscriptions previously tracked by that broker's runtime client. An empty topic maps to `#`.
- MQTT messages are streamed to the browser and are not stored as application history. Refreshing the page clears the displayed messages; restarting the application also does not restore messages.
- Broker configurations and user accounts are persistent application data. The selected storage location is described in the technical specification.
- Published message QoS is selected from `0`, `1`, and `2`; retain is enabled only when the form checkbox is selected.

## User and System Interactions

### Register and sign in

1. The visitor opens the registration page and supplies a username, password, and confirmation.
2. The application checks for matching passwords and an existing username.
3. If valid, the application stores a password hash, establishes a session, and redirects to the broker page. Otherwise, it displays an error and leaves the visitor unauthenticated.
4. Returning users submit their credentials on the login page. Successful login redirects to broker management; invalid credentials display an error.
5. Logging out removes the user's session identifier and redirects to login.

### Configure and connect a broker

1. The authenticated user adds a broker with a host/IP, optional name, port, and optional credentials.
2. The broker appears in that user's broker list with its current runtime status.
3. Selecting **Connect** starts an asynchronous MQTT connection. The list later reflects a successful connection or a connection error when reported by the MQTT client.
4. The user can disconnect, edit, or delete a broker. Editing or deleting removes the current runtime MQTT client.

### Subscribe and receive messages

1. The user opens the subscription page and chooses a connected broker.
2. The user submits a topic. An empty value means `#`; otherwise, the submitted topic is used.
3. The broker client replaces its prior subscription and subscribes to the requested topic.
4. When a message arrives from the broker, the application emits a `mqtt_message` Socket.IO event to the room for that user. The browser appends the message to its live display.
5. The user can stop listening, which clears the client's tracked subscriptions, or clear only the current browser display.

### Publish a message

1. The user opens the publish page, chooses an available connected broker, and submits a topic, payload, QoS, and optional retain flag.
2. If a connected client is available and the broker belongs to the user, the application invokes the MQTT client's publish operation and displays a success flash message.
3. If the broker is disconnected or no client is available, the application displays an error instead of publishing.

## Validation and Error Handling

### Implemented user-visible cases

- Registration reports password mismatch and duplicate username errors.
- Login reports invalid credentials without distinguishing an unknown username from a wrong password.
- Protected pages redirect a request without a logged-in session to login.
- Broker connection failures reported by the MQTT callback are reflected as an error status and error text in the broker list.
- The subscription form reports when no broker is selected. Attempting to publish without an available connected broker displays an error.
- Requests for a broker that is not owned by the current user are not returned as that user's broker in the broker list; broker edit and delete lookup is scoped by the session user.

### Current limitations and ToDos

- Several values are converted directly to integers or passed to MQTT operations. Malformed direct POST requests (for example, invalid port, broker ID, or QoS values) do not have comprehensive application-level validation and may result in errors rather than a friendly form message.
- The browser forms use required-field hints, but server-side validation is not comprehensive. No password length/complexity policy is implemented in the registration handler.
- If a subscription request refers to a broker without an active client, the current handler does not display a specific error.
- The publish route reports that a publish operation was invoked; it does not check the MQTT publish result or wait for broker acknowledgement before showing success.
- **ToDo:** confirm account-creation policy, including whether public self-registration is intended for every deployment and whether a first-user/admin setup policy exists.
- **ToDo:** review input-validation and error-message behavior if stronger guarantees are required.

## Acceptance Criteria

These criteria describe checks for the current baseline; they are not claims that a new automated test has been added for every item.

1. Given a new username and matching password confirmation, registration creates an account, establishes a session, and redirects to broker management.
2. Given an existing username or mismatched password confirmation, registration does not create a logged-in account and provides the corresponding error message.
3. Given valid credentials, login establishes an authenticated session; given invalid credentials, login displays a generic invalid-credentials message.
4. Given a user with broker records, the broker page shows that user's records and does not show records owned by another user.
5. Given an empty broker name on creation, the resulting broker name defaults to the submitted host/IP; the add form's default port is `1883`.
6. Given a broker connect request, the application starts an asynchronous connection attempt and reflects later connected/error status from the MQTT client rather than treating initiation as proof of successful connection.
7. Given a connected broker and an empty subscription topic, the MQTT client subscribes to `#`; given a non-empty topic, it subscribes to that topic after removing its previously tracked subscription.
8. Given an MQTT message on a subscribed topic, an authenticated user's Socket.IO session receives a `mqtt_message` event containing broker ID/name, timestamp, topic, and payload, and the subscription page displays it.
9. Given a publish request to a connected broker owned by the user, the MQTT client receives the topic, payload, selected QoS, and retain flag from the request.
10. Given a publish request when the selected broker client is disconnected or absent, the application reports “Broker not connected” and does not invoke publish.
11. Given an application restart, user and broker records remain in the configured SQLite database, while runtime connection state and active subscriptions are not restored.
12. Given a page refresh or use of **Clear Messages**, the page's message display is cleared; no application message-history record is available to restore it.
