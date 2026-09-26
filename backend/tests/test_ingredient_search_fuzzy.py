from fastapi.testclient import TestClient

from app.main import app
from app.models.nutrition import Ingredient


client = TestClient(app)


def test_ingredient_search_falls_back_to_a_close_name(as_admin, db_session):
    db = db_session
    ingredient = Ingredient(name="测试牛筋面")
    db.add(ingredient)
    db.commit()

    try:
        response = client.get(
            "/api/v1/ingredients",
            params={"q": "测试牛筋丸", "sort_by": "name", "limit": 20},
        )

        assert response.status_code == 200
        assert any(item["id"] == ingredient.id for item in response.json()["items"])
    finally:
        db.query(Ingredient).filter(Ingredient.id == ingredient.id).delete()
        db.commit()

def test_search_by_name_falls_back_to_a_close_name(as_admin, db_session):
    db = db_session
    ingredient = Ingredient(name="测试牛肉面")
    db.add(ingredient)
    db.commit()

    try:
        response = client.get("/api/v1/ingredients/search-by-name/测试牛肉丸")

        assert response.status_code == 200
        assert any(item["id"] == ingredient.id for item in response.json())
    finally:
        db.query(Ingredient).filter(Ingredient.id == ingredient.id).delete()
        db.commit()
