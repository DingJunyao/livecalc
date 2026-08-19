from datetime import datetime
from decimal import Decimal

from fastapi.testclient import TestClient

from app.main import app
from app.models.change_proposal import ChangeProposal
from app.models.product_entity import Product
from app.models.product import ProductRecord
from app.models.nutrition import Ingredient
from app.models.recipe import Recipe, RecipeIngredient
from app.models.unit import Unit
from app.models.user import User
from app.api.recipes import _pending_recipe_cost_rows
from app.services.proposals.executors.recipe_edit import RecipeEditExecutor


client = TestClient(app)


def test_pending_added_ingredient_gets_navigation_id_and_cost(
    db_session,
    as_non_admin,
    monkeypatch,
):
    db = db_session
    if db.query(User).filter(User.id == 2).first() is None:
        db.add(User(
            id=2,
            username="pending_cost_user",
            email="pending-cost-user@test.local",
            password_hash="x",
        ))

    gram = db.get(Unit, 3)
    created_gram = gram is None
    if gram is None:
        gram = Unit(
            id=3,
            name="pending cost gram",
            abbreviation="pcg",
            unit_type="mass",
            si_factor=1.0,
            is_si_base=True,
            is_standard=True,
        )
        db.add(gram)
        db.flush()
    ingredient = Ingredient(name="pending cost official courgette")
    db.add(ingredient)
    db.flush()
    product = Product(
        name="pending cost courgette product",
        ingredient_id=ingredient.id,
    )
    db.add(product)
    db.flush()
    record = ProductRecord(
        user_id=2,
        product_id=product.id,
        product_name=product.name,
        price=Decimal("10.00"),
        original_quantity=100,
        original_unit_id=gram.id,
        standard_quantity=100,
        standard_unit_id=gram.id,
        record_type="price",
        recorded_at=datetime.now(),
    )
    recipe = Recipe(
        name="pending cost recipe",
        source="custom",
        servings=1,
        user_id=2,
        is_public=True,
    )
    db.add_all([record, recipe])
    db.flush()
    ingredient_proposal = ChangeProposal(
        entity_type="ingredient",
        entity_id=ingredient.id,
        action="update",
        payload={"name": "pending cost draft courgette"},
        proposer_id=2,
    )
    db.add(ingredient_proposal)
    db.commit()

    recipe_payload = {
        "update_data": {
            "ingredients": [
                {
                    "ingredient_name": "pending cost draft courgette",
                    "quantity": "100",
                    "unit_id": gram.id,
                    "is_optional": False,
                }
            ]
        }
    }

    class Proposal:
        id = 92001
        entity_id = recipe.id
        action = "update"
        payload = recipe_payload
        proposer_id = 2

    monkeypatch.setattr(
        "app.services.proposals.pending.get_pending_proposals",
        lambda db, entity_types, entity_id, user_id: [Proposal()],
    )

    try:
        detail = client.get(f"/api/v1/recipes/{recipe.id}")
        assert detail.status_code == 200
        item = detail.json()["pending_proposals"][0]["payload"]["update_data"]["ingredients"][0]
        assert item["ingredient_id"] == ingredient.id
        assert item["id"] == -1
        assert item["unit"] == gram.abbreviation

        cost = client.get(f"/api/v1/recipes/{recipe.id}/cost")
        assert cost.status_code == 200
        body = cost.json()
        assert float(body["total_cost"]) > 0
        assert body["cost_breakdown"][0]["ingredient_id"] == ingredient.id
        assert body["cost_breakdown"][0]["recipe_ingredient_id"] == -1

        executor = RecipeEditExecutor()
        executor.apply(db, Proposal())
        saved = db.query(RecipeIngredient).filter(
            RecipeIngredient.recipe_id == recipe.id,
            RecipeIngredient.ingredient_id == ingredient.id,
        ).first()
        assert saved is not None
        assert saved.quantity == "100"
    finally:
        db.query(ChangeProposal).filter(
            ChangeProposal.id == ingredient_proposal.id
        ).delete()
        db.query(RecipeIngredient).filter(
            RecipeIngredient.recipe_id == recipe.id
        ).delete()
        db.query(Recipe).filter(Recipe.id == recipe.id).delete()
        db.query(ProductRecord).filter(ProductRecord.id == record.id).delete()
        db.query(Product).filter(Product.id == product.id).delete()
        db.query(Ingredient).filter(Ingredient.id == ingredient.id).delete()
        if created_gram:
            db.query(Unit).filter(Unit.id == gram.id).delete()
        db.commit()
