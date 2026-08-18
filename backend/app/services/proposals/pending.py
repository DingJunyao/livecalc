"""查询当前用户对某实体是否有待审提议。"""
from typing import List, Optional, Sequence
from sqlalchemy.orm import Session
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
