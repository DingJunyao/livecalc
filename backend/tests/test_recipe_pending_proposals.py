from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app
from app.models.change_proposal import ChangeProposal
from app.models.recipe import Recipe
from app.models.user import User
from app.services.proposals.pending import get_pending_proposals


client = TestClient(app)


def test_get_pending_proposals_returns_only_current_users_active_items(db_session):
    db = db_session
    user = User(username="pending_recipe_user", email="pending-recipe-user@test.local", password_hash="x")
    other_user = User(username="pending_recipe_other", email="pending-recipe-other@test.local", password_hash="x")
    db.add_all([user, other_user])
    db.flush()

    recipes = [
        ChangeProposal(
            entity_type="recipe",
            entity_id=987001,
            action="update",
            payload={"update_data": {"tips": ["old"]}},
            proposer_id=user.id,
            created_at=datetime(2024, 1, 1, 10, 0, 0),
        ),
        ChangeProposal(
            entity_type="recipe_edit",
            entity_id=987001,
            action="update",
            payload={"update_data": {"cooking_steps": []}},
            proposer_id=user.id,
            created_at=datetime(2024, 1, 2, 10, 0, 0),
        ),
        ChangeProposal(
            entity_type="recipe",
            entity_id=987001,
            action="update",
            payload={"update_data": {"other_user": True}},
            proposer_id=other_user.id,
            created_at=datetime(2024, 1, 3, 10, 0, 0),
        ),
        ChangeProposal(
            entity_type="recipe_edit",
            entity_id=987001,
            action="update",
            payload={"update_data": {"rejected": True}},
            proposer_id=user.id,
            status="rejected",
            created_at=datetime(2024, 1, 4, 10, 0, 0),
        ),
        ChangeProposal(
            entity_type="nutrition",
            entity_id=987001,
            action="update",
            payload={"update_data": {"wrong_type": True}},
            proposer_id=user.id,
            created_at=datetime(2024, 1, 5, 10, 0, 0),
        ),
    ]
    recipes.append(
        ChangeProposal(
            entity_type="recipe",
            entity_id=987001,
            action="update",
            payload={"update_data": {"inactive": True}},
            proposer_id=user.id,
            is_active=False,
            created_at=datetime(2024, 1, 6, 10, 0, 0),
        )
    )
    db.add_all(recipes)
    db.commit()

    try:
        result = get_pending_proposals(db, ("recipe", "recipe_edit"), 987001, user.id)

        assert [proposal.id for proposal in result] == [recipes[0].id, recipes[1].id]
    finally:
        db.query(ChangeProposal).filter(ChangeProposal.entity_id == 987001).delete()
        db.query(User).filter(User.id.in_([user.id, other_user.id])).delete()
        db.commit()


def test_recipe_detail_returns_all_pending_proposals_and_compatible_latest(
    db_session,
    as_non_admin,
    monkeypatch,
):
    recipe = Recipe(
        name="pending proposals detail recipe",
        source="custom",
        servings=1,
        user_id=2,
        is_public=True,
    )
    db_session.add(recipe)
    db_session.commit()

    class Proposal:
        def __init__(self, proposal_id, payload):
            self.id = proposal_id
            self.action = "update"
            self.payload = payload

    proposals = [
        Proposal(91001, {"update_data": {"tips": ["first"]}}),
        Proposal(91002, {"update_data": {"cooking_steps": []}}),
    ]
    monkeypatch.setattr(
        "app.services.proposals.pending.get_pending_proposals",
        lambda db, entity_types, entity_id, user_id: proposals,
    )

    try:
        response = client.get(f"/api/v1/recipes/{recipe.id}")

        assert response.status_code == 200
        data = response.json()
        assert [item["id"] for item in data["pending_proposals"]] == [91001, 91002]
        assert data["pending_proposals"][0]["payload"]["update_data"]["tips"] == ["first"]
        assert data["pending_proposal"]["id"] == 91002
        assert data["pending_proposal"]["payload"]["update_data"] == {"cooking_steps": []}
    finally:
        db_session.query(Recipe).filter(Recipe.id == recipe.id).delete()
        db_session.commit()
