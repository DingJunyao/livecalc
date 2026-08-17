"""原料最新价批量接口测试。"""

from conftest import TestingSessionLocal, engine
from app.core.database import Base


def _create_ingredient(name: str) -> int:
    from app.models.nutrition import Ingredient

    db = TestingSessionLocal()
    try:
        db.add(Ingredient(name=name))
        db.commit()
        row = db.query(Ingredient).filter(Ingredient.name == name).one()
        return row.id
    finally:
        db.close()


def test_latest_price_batch_uses_one_request_for_multiple_ingredients(as_admin):
    from starlette.testclient import TestClient

    from app.main import app

    Base.metadata.create_all(bind=engine)
    id1 = _create_ingredient("批量最新价原料A")
    id2 = _create_ingredient("批量最新价原料B")

    client = TestClient(app)
    response = client.get(
        "/api/v1/nutrition/ingredients/latest-price/batch",
        params={"ingredient_ids": f"{id1},{id2},{id1}"},
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert set(items) == {str(id1), str(id2)}
    assert items[str(id1)]["average_price"] is None
    assert items[str(id2)]["average_price"] is None


def test_latest_price_batch_rejects_invalid_ids(as_admin):
    from starlette.testclient import TestClient

    from app.main import app

    client = TestClient(app)
    response = client.get(
        "/api/v1/nutrition/ingredients/latest-price/batch",
        params={"ingredient_ids": "1,abc"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "ingredient_ids 包含无效ID"
