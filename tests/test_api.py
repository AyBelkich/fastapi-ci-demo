import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient
import main

client = TestClient(main.app)


@pytest.fixture(autouse=True)
def reset_state():
    # clears storage before every test
    main.items_by_id.clear()


def test_health_ok():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_create_item_returns_201():
    r = client.post("/items", json={"name": "Apple", "price": 1.23})
    assert r.status_code == 201
    body = r.json()
    assert "id" in body
    assert body["name"] == "Apple"


def test_duplicate_name_returns_400():
    client.post("/items", json={"name": "Apple", "price": 1.23})
    r2 = client.post("/items", json={"name": "Apple", "price": 9.99})
    assert r2.status_code == 400
    assert r2.json()["detail"] == "Item already exists"


def test_get_item_by_id_works():
    created = client.post("/items", json={"name": "Book", "price": 9.99}).json()
    item_id = created["id"]

    r = client.get(f"/items/{item_id}")
    assert r.status_code == 200
    assert r.json()["id"] == item_id


def test_delete_item_then_get_404():
    created = client.post("/items", json={"name": "Pen", "price": 0.99}).json()
    item_id = created["id"]

    r_del = client.delete(f"/items/{item_id}")
    assert r_del.status_code == 204

    r_get = client.get(f"/items/{item_id}")
    assert r_get.status_code == 404

def test_get_missing_item_returns_404():
    r = client.get("/items/does-not-exist")
    assert r.status_code == 404
