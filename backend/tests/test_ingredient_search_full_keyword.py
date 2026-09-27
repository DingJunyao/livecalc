from fastapi.testclient import TestClient

from app.main import app
from app.models.nutrition import Ingredient
from app.models.product_entity import Product


client = TestClient(app)


def test_ingredient_search_returns_a_full_keyword_match(as_admin, db_session):
    db = db_session
    ingredient = Ingredient(name="牛筋丸")
    db.add(ingredient)
    db.flush()
    product = Product(name="思念潮汕牛筋丸", ingredient_id=ingredient.id)
    db.add(product)
    db.commit()

    try:
        response = client.get(
            "/api/v1/ingredients",
            params={"q": "牛筋丸", "limit": 20, "sort_by": "price_records"},
        )

        assert response.status_code == 200
        assert any(item["id"] == ingredient.id for item in response.json()["items"])
    finally:
        db.query(Product).filter(Product.id == product.id).delete()
        db.query(Ingredient).filter(Ingredient.id == ingredient.id).delete()
        db.commit()
