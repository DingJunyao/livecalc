from fastapi.testclient import TestClient

from app.main import app
from app.models.change_proposal import ChangeProposal
from app.models.ingredient_hierarchy import IngredientHierarchy
from app.models.nutrition import Ingredient
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.recipe import Recipe, RecipeIngredient
from app.models.unit import Unit
from app.models.user import User


client = TestClient(app)


def test_current_user_sees_pending_ingredient_names_across_views(
    db_session,
    as_non_admin,
):
    db = db_session
    user = db.get(User, 2)
    if user is None:
        db.add(User(
            id=2,
            username="pending-ingredient-draft-user",
            email="pending-ingredient-draft-user@test.local",
            password_hash="x",
        ))
        db.flush()

    zucchini = Ingredient(name="pending draft zucchini")
    pumpkin = Ingredient(name="pending draft pumpkin")
    recipe = Recipe(
        name="pending draft recipe",
        source="custom",
        servings=1,
        user_id=2,
        is_public=True,
    )
    unit = Unit(
        name="pending draft gram",
        abbreviation="pd-g",
        unit_type="mass",
    )
    db.add_all([zucchini, pumpkin, recipe, unit])
    db.flush()

    recipe_ingredient = RecipeIngredient(
        recipe_id=recipe.id,
        ingredient_id=zucchini.id,
    )
    product = Product(name="pending draft zucchini", ingredient_id=zucchini.id)
    db.add_all([recipe_ingredient, product])
    db.flush()
    record = ProductRecord(
        user_id=2,
        product_id=product.id,
        product_name=product.name,
        price=1,
        original_quantity=1,
        original_unit_id=unit.id,
        standard_quantity=1,
        standard_unit_id=unit.id,
    )
    db.add(record)
    db.flush()

    ingredient_proposal = ChangeProposal(
        entity_type="ingredient",
        entity_id=zucchini.id,
        action="update",
        payload={"name": "pending draft courgette", "updated_by": 2},
        proposer_id=2,
    )
    product_proposal = ChangeProposal(
        entity_type="product",
        entity_id=product.id,
        action="update",
        payload={"name": "pending draft product courgette", "updated_by": 2},
        proposer_id=2,
    )
    hierarchy_proposal = ChangeProposal(
        entity_type="hierarchy",
        entity_id=None,
        action="create",
        payload={
            "parent_id": zucchini.id,
            "child_id": pumpkin.id,
            "relation_type": "contains",
            "strength": 60,
        },
        proposer_id=2,
    )
    db.add_all([ingredient_proposal, product_proposal, hierarchy_proposal])
    db.commit()

    try:
        list_response = client.get(
            "/api/v1/ingredients",
            params={"q": "pending draft zucchini", "sort_by": "name"},
        )
        assert list_response.status_code == 200
        list_item = next(
            item
            for item in list_response.json()["items"]
            if item["id"] == zucchini.id
        )
        assert list_item["name"] == "pending draft courgette"
        assert list_item["pending_proposal"]["payload"]["name"] == "pending draft courgette"

        recipe_response = client.get(f"/api/v1/recipes/{recipe.id}")
        assert recipe_response.status_code == 200
        assert recipe_response.json()["ingredients"][0]["name"] == "pending draft courgette"

        records_response = client.get(
            "/api/v1/products",
            params={"product_id": product.id},
        )
        assert records_response.status_code == 200
        assert (
            records_response.json()["items"][0]["product_name"]
            == "pending draft product courgette"
        )

        products_response = client.get(
            "/api/v1/products/entity",
            params={"ingredient_id": zucchini.id},
        )
        assert products_response.status_code == 200
        product_item = products_response.json()["items"][0]
        assert product_item["name"] == "pending draft product courgette"
        assert product_item["ingredient_name"] == "pending draft courgette"
        assert (
            product_item["pending_proposal"]["payload"]["name"]
            == "pending draft product courgette"
        )

        product_search_response = client.get(
            "/api/v1/products/entity",
            params={"search": "pending draft product courgette"},
        )
        assert product_search_response.status_code == 200
        assert any(
            item["id"] == product.id
            and item["name"] == "pending draft product courgette"
            for item in product_search_response.json()["items"]
        )

        product_detail_response = client.get(
            f"/api/v1/products/entity/{product.id}"
        )
        assert product_detail_response.status_code == 200
        assert product_detail_response.json()["name"] == "pending draft product courgette"
        assert (
            product_detail_response.json()["ingredient_name"]
            == "pending draft courgette"
        )

        autocomplete_response = client.get(
            "/api/v1/products/autocomplete",
            params={"q": "pending draft product courgette"},
        )
        assert autocomplete_response.status_code == 200
        assert autocomplete_response.json()[0]["name"] == "pending draft product courgette"

        proposals_response = client.get(
            "/api/v1/proposals",
            params={"status": "pending", "scope": "mine"},
        )
        assert proposals_response.status_code == 200
        hierarchy_item = next(
            item
            for item in proposals_response.json()
            if item["id"] == hierarchy_proposal.id
        )
        assert hierarchy_item["snapshot"]["_parent_id_name"] == "pending draft zucchini"
        assert hierarchy_item["snapshot"]["_child_id_name"] == "pending draft pumpkin"
    finally:
        db.query(ChangeProposal).filter(
            ChangeProposal.id.in_(
                [
                    ingredient_proposal.id,
                    product_proposal.id,
                    hierarchy_proposal.id,
                ]
            )
        ).delete(synchronize_session=False)
        db.query(ProductRecord).filter(ProductRecord.id == record.id).delete()
        db.query(Product).filter(Product.id == product.id).delete()
        db.query(RecipeIngredient).filter(
            RecipeIngredient.id == recipe_ingredient.id
        ).delete()
        db.query(Recipe).filter(Recipe.id == recipe.id).delete()
        db.query(IngredientHierarchy).filter(
            (IngredientHierarchy.parent_id == zucchini.id)
            | (IngredientHierarchy.child_id == zucchini.id)
        ).delete(synchronize_session=False)
        db.query(Ingredient).filter(
            Ingredient.id.in_([zucchini.id, pumpkin.id])
        ).delete(synchronize_session=False)
        db.query(Unit).filter(Unit.id == unit.id).delete()
        db.commit()
