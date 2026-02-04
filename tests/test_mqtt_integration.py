import time
from unittest.mock import MagicMock
from database import db, Broker
from mqtt_manager import add_client, remove_client, set_socketio


def test_mqtt_flow(app, mqtt_broker):
    """Verify full MQTT cycle: connect, subscribe, publish, and broadcast via Socket.IO."""
    with app.app_context():
        # Mock Socket.IO instance
        mock_socketio = MagicMock()
        set_socketio(mock_socketio)

        # 1. Setup a test broker in DB
        broker_obj = Broker(
            name="Integration Test Broker",
            ip=mqtt_broker["host"],
            port=mqtt_broker["port"],
            user_id=1,  # Mock user
        )
        db.session.add(broker_obj)
        db.session.commit()

        # 2. Connect
        client = add_client(broker_obj)
        connected, error = client.connect()
        assert connected is True, f"Failed to connect: {error}"

        # Wait for on_connect to set is_connected to True
        for _ in range(50):  # 5 seconds
            if client.is_connected:
                break
            time.sleep(0.1)
        assert client.is_connected is True, (
            f"Client connected but is_connected flag not set. Error: {client.connection_error}"
        )

        try:
            # 3. Subscribe
            topic = "test/integration"
            client.update_subscription(topic)
            time.sleep(1)  # Wait for subscription to be processed

            # 4. Publish
            message = "Hello MQTT"
            client.publish(topic, message)

            # 5. Wait for message to be broadcast via Socket.IO
            # The MQTT on_message callback should trigger socketio.emit()
            for _ in range(50):  # 5 seconds timeout
                if mock_socketio.emit.called:
                    break
                time.sleep(0.1)

            # 6. Verify Socket.IO emit was called with correct data
            assert mock_socketio.emit.called, "Socket.IO emit was not called"
            call_args = mock_socketio.emit.call_args
            assert call_args[0][0] == "mqtt_message"  # Event name
            message_data = call_args[0][1]  # Data payload
            assert message_data["topic"] == topic
            assert message_data["payload"] == message
            assert "timestamp" in message_data
            assert call_args[1]["room"] == "user_1"  # Room matches user_id

        finally:
            remove_client(broker_obj.id)


def test_mqtt_connection_failure(app):
    """Verify that connection attempts don't block (async behavior)."""
    with app.app_context():
        broker_obj = Broker(
            name="Unreachable Broker",
            ip="192.0.2.1",  # Non-routable IP
            port=1883,
            user_id=1,
        )

        client = add_client(broker_obj)
        connected, error = client.connect()

        # connect_async() should return immediately with success
        # (connection is initiated but not complete)
        assert connected is True
        assert error is None

        # The connection should still be in progress (not connected yet)
        assert client.is_connected is False

        remove_client(broker_obj.id)
