"""查询当前用户对某实体是否有待审提议。"""
from typing import List, Optional, Sequence
from sqlalchemy.orm import Session, joinedload
from app.models.change_proposal import ChangeProposal


def get_pending_proposal(db: Session, entity_type: str, entity_id: int, user_id: int) -> Optional[ChangeProposal]:
    """返回当前用户对该实体的一条待审提议，没有则返回 None。

    查询条件：匹配 entity_type/entity_id/proposer_id，status=pending 且 is_active。
    同一对 (entity_type, entity_id, user_id) 可能有多条待审提议，取最新一条。
    """
    return db.query(ChangeProposal).filter(
        ChangeProposal.entity_type == entity_type,
        ChangeProposal.entity_id == entity_id,
        ChangeProposal.proposer_id == user_id,
        ChangeProposal.status == "pending",
        ChangeProposal.is_active.is_(True),
    ).order_by(ChangeProposal.created_at.desc().nullslast()).first()


def get_pending_proposals(
    db: Session,
    entity_types: Sequence[str],
    entity_id: int,
    user_id: int,
) -> List[ChangeProposal]:
    """Return every active pending proposal, oldest first.

    A recipe can have proposals under both the legacy `recipe` type and the
    section-oriented `recipe_edit` type. Detail pages need the complete list so
    users can see all pending changes, not only the newest one.
    """
    return db.query(ChangeProposal).filter(
        ChangeProposal.entity_type.in_(tuple(entity_types)),
        ChangeProposal.entity_id == entity_id,
        ChangeProposal.proposer_id == user_id,
        ChangeProposal.status == "pending",
        ChangeProposal.is_active.is_(True),
    ).order_by(
        ChangeProposal.created_at.asc().nullslast(),
        ChangeProposal.id.asc(),
    ).all()


def get_latest_pending_proposals(
    db: Session,
    entity_type: str,
    entity_ids: Sequence[int],
    user_id: int,
) -> dict:
    """Return the newest active pending proposal for each entity id."""
    if not entity_ids:
        return {}
    proposals = db.query(ChangeProposal).filter(
        ChangeProposal.entity_type == entity_type,
        ChangeProposal.entity_id.in_(tuple(entity_ids)),
        ChangeProposal.proposer_id == user_id,
        ChangeProposal.status == "pending",
        ChangeProposal.is_active.is_(True),
    ).all()
    return {
        proposal.entity_id: proposal
        for proposal in sorted(proposals, key=lambda item: item.id)
        if proposal.entity_id is not None
    }


def get_pending_update_value(proposal, field: str):
    if proposal is None or proposal.action != "update":
        return None
    value = (proposal.payload or {}).get(field)
    return value if value not in (None, "") else None


def build_product_display_overrides(db: Session, products, current_user) -> dict:
    """Build proposer-visible product names without changing official rows."""
    if not products or getattr(current_user, "is_admin", False):
        return {}

    product_proposals = get_latest_pending_proposals(
        db,
        "product",
        [product.id for product in products],
        current_user.id,
    )

    target_ingredient_ids = {
        product.ingredient_id
        for product in products
        if product.ingredient_id is not None
    }
    for proposal in product_proposals.values():
        ingredient_id = get_pending_update_value(proposal, "ingredient_id")
        if isinstance(ingredient_id, int):
            target_ingredient_ids.add(ingredient_id)

    ingredient_proposals = get_latest_pending_proposals(
        db,
        "ingredient",
        list(target_ingredient_ids),
        current_user.id,
    )
    from app.models.nutrition import Ingredient

    official_ingredient_names = {
        ingredient.id: ingredient.name
        for ingredient in db.query(Ingredient.id, Ingredient.name)
        .filter(Ingredient.id.in_(target_ingredient_ids))
        .all()
    } if target_ingredient_ids else {}

    overrides = {}
    for product in products:
        proposal = product_proposals.get(product.id)
        target_ingredient_id = get_pending_update_value(
            proposal, "ingredient_id"
        )
        if not isinstance(target_ingredient_id, int):
            target_ingredient_id = product.ingredient_id

        ingredient_proposal = ingredient_proposals.get(target_ingredient_id)
        ingredient_name = (
            get_pending_update_value(ingredient_proposal, "name")
            or official_ingredient_names.get(target_ingredient_id)
            or (product.ingredient.name if product.ingredient else None)
        )
        inherited_ingredient_name = (
            product.ingredient.name if product.ingredient else None
        )
        product_name = get_pending_update_value(proposal, "name")
        if product_name is None and product.name == inherited_ingredient_name:
            product_name = get_pending_update_value(
                ingredient_proposal, "name"
            )

        overrides[product.id] = {
            "name": product_name or product.name,
            "ingredient_id": target_ingredient_id,
            "ingredient_name": ingredient_name,
            "proposal": proposal,
        }
    return overrides


def find_product_ids_with_pending_names(db: Session, search: str, current_user) -> set:
    """Find products whose proposer-visible name matches a search."""
    if not search or getattr(current_user, "is_admin", False):
        return set()

    from app.models.product_entity import Product

    proposals = db.query(ChangeProposal).filter(
        ChangeProposal.proposer_id == current_user.id,
        ChangeProposal.status == "pending",
        ChangeProposal.is_active.is_(True),
        ChangeProposal.entity_type.in_(("product", "ingredient")),
    ).all()
    product_ids = {
        proposal.entity_id
        for proposal in proposals
        if proposal.entity_type == "product"
        and proposal.entity_id is not None
    }
    ingredient_ids = {
        proposal.entity_id
        for proposal in proposals
        if proposal.entity_type == "ingredient"
        and proposal.entity_id is not None
        and get_pending_update_value(proposal, "name") is not None
    }
    if ingredient_ids:
        product_ids.update(
            product_id
            for (product_id,) in db.query(Product.id)
            .filter(
                Product.ingredient_id.in_(ingredient_ids),
                Product.is_active.is_(True),
            )
            .all()
        )
    if not product_ids:
        return set()

    products = (
        db.query(Product)
        .options(joinedload(Product.ingredient))
        .filter(Product.id.in_(product_ids))
        .all()
    )
    search_lower = search.lower()
    overrides = build_product_display_overrides(db, products, current_user)
    matches = set()
    for product in products:
        display = overrides.get(product.id, {})
        ingredient_name = display.get(
            "ingredient_name",
            product.ingredient.name if product.ingredient else "",
        ) or ""
        if (
            search_lower in display.get("name", product.name).lower()
            or search_lower in ingredient_name.lower()
        ):
            matches.add(product.id)
    return matches
