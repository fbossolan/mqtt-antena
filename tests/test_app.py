import os
from app import app


def test_data_dir():
    uri = app.config["SQLALCHEMY_DATABASE_URI"]
    # Check if the path ends correctly for either HA or local dev
    assert uri.endswith("/data/antena.db") or uri.endswith("/antena.db")

    if os.path.exists("/data"):
        assert uri == "sqlite:////data/antena.db"
    else:
        assert uri.startswith("sqlite:///")
        assert uri.endswith("data/antena.db")
