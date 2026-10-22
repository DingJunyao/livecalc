"""商品/原料数量关联 API。

语义：一条关联就是一句等式
    from_quantity [from_unit] of from_entity = to_quantity [to_unit] of to_entity

写操作沿用现有治理分流：管理员直写，普通用户提交提议待审。
"""
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.i18n import api_message
from app.core.security import get_current_user
from app.models.entity_quantity_link import EntityQuantityLink
from app.models.user import User
from app.schemas.entity_quantity_link import (
    EntityQuantityLinkCreate,
    EntityQuantityLinkEnvelope,
    EntityQuantityLinkOut,
    EntityQuantityLinkUpdate,
)
from app.services.calc_scope import resolve_region_param
from app.services.entity_link_service import (
    get_entity,
    get_links_for_entity,
    serialize_link,
    serialize_links,
    validate_entity_type,
    validate_link_payload,
)
from app.services.proposals import service as proposal_service

router = APIRouter(tags=["实体数量关联"])


def _json_safe(value):
    if isinstance(value, Decimal):
        return str(value)
    return value


def _payload_json(payload: dict) -> dict:
    return {k: _json_safe(v) for k, v in payload.items()}


def _require_link(
    db: Session,
    entity_type: str,
    entity_id: int,
    link_id: int,
) -> EntityQuantityLink:
    validate_entity_type(entity_type)
    link = (
        db.query(EntityQuantityLink)
        .filter(
            EntityQuantityLink.id == link_id,
            EntityQuantityLink.is_active.is_(True),
        )
        .first()
    )
    if link is None:
        raise LocalizedHTTPException(status_code=404, message="关联不存在或已删除")
    if not (
        (link.from_type == entity_type and link.from_id == entity_id)
        or (link.to_type == entity_type and link.to_id == entity_id)
    ):
        raise LocalizedHTTPException(status_code=404, message="关联不属于当前商品/原料")
    return link


def _transient_link(payload: dict) -> EntityQuantityLink:
    return EntityQuantityLink(
        id=0,
        from_type=payload["from_type"],
        from_id=payload["from_id"],
        from_quantity=payload["from_quantity"],
        from_unit=payload["from_unit"],
        to_type=payload["to_type"],
        to_id=payload["to_id"],
        to_quantity=payload["to_quantity"],
        to_unit=payload["to_unit"],
        note=payload.get("note"),
        is_active=True,
    )


@router.get(
    "/entities/{entity_type}/{entity_id}/quantity-links",
    response_model=EntityQuantityLinkEnvelope,
)
def list_quantity_links(
    entity_type: str,
    entity_id: int,
    include_prices: bool = Query(False, description="是否附带对方最新价与当前等价价"),
    region_id: Optional[int] = Query(None, description="按商家地区子树过滤"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    validate_entity_type(entity_type)
    if get_entity(db, entity_type, entity_id) is None:
        raise LocalizedHTTPException(status_code=404, message="当前商品/原料不存在或已删除")
    region_id = resolve_region_param(db, current_user, region_id)
    links = get_links_for_entity(db, entity_type, entity_id)
    items = serialize_links(
        db, links, entity_type, entity_id,
        include_prices=include_prices,
        user_id=current_user.id if current_user else None,
        region_id=region_id,
    )
    return {"items": items}


@router.post(
    "/entities/{entity_type}/{entity_id}/quantity-links",
    response_model=EntityQuantityLinkOut,
    status_code=201,
)
def create_quantity_link(
    entity_type: str,
    entity_id: int,
    data: EntityQuantityLinkCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    validate_entity_type(entity_type)
    payload = {
        "from_type": entity_type,
        "from_id": entity_id,
        "to_type": data.to_type,
        "to_id": data.to_id,
        "from_quantity": data.from_quantity,
        "from_unit": data.from_unit,
        "to_quantity": data.to_quantity,
        "to_unit": data.to_unit,
        "note": data.note,
    }
    validated = validate_link_payload(db, payload)

    if current_user.is_admin:
        proposal = proposal_service.apply_as_admin(
            db, entity_type="entity_quantity_link", entity_id=None,
            action="create", payload=_payload_json(validated), admin=current_user,
        )
        db.commit()
        link = (
            db.query(EntityQuantityLink)
            .filter(EntityQuantityLink.id == proposal.entity_id)
            .first()
        )
        if link is None:
            raise LocalizedHTTPException(status_code=500, message="关联创建失败")
        result = serialize_link(db, link, entity_type, entity_id)
        if result is None:
            raise LocalizedHTTPException(status_code=500, message="关联创建失败")
        return result

    proposal_service.submit(
        db, entity_type="entity_quantity_link", entity_id=None,
        action="create", payload=_payload_json(validated), proposer=current_user,
    )
    db.commit()
    result = serialize_link(
        db, _transient_link(validated), entity_type, entity_id, pending=True,
    )
    if result is None:
        raise LocalizedHTTPException(status_code=500, message="关联创建失败")
    return result


@router.put(
    "/entities/{entity_type}/{entity_id}/quantity-links/{link_id}",
    response_model=EntityQuantityLinkOut,
)
def update_quantity_link(
    entity_type: str,
    entity_id: int,
    link_id: int,
    data: EntityQuantityLinkUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    link = _require_link(db, entity_type, entity_id, link_id)
    update_data = data.model_dump(exclude_unset=True)
    merged = {
        "from_type": link.from_type,
        "from_id": link.from_id,
        "from_quantity": update_data.get("from_quantity", link.from_quantity),
        "from_unit": update_data.get("from_unit", link.from_unit),
        "to_type": link.to_type,
        "to_id": link.to_id,
        "to_quantity": update_data.get("to_quantity", link.to_quantity),
        "to_unit": update_data.get("to_unit", link.to_unit),
        "note": update_data.get("note", link.note),
    }
    validated = validate_link_payload(db, merged, exclude_id=link.id)
    payload = {
        "from_quantity": validated["from_quantity"],
        "from_unit": validated["from_unit"],
        "to_quantity": validated["to_quantity"],
        "to_unit": validated["to_unit"],
        "note": validated["note"],
    }

    if current_user.is_admin:
        proposal_service.apply_as_admin(
            db, entity_type="entity_quantity_link", entity_id=link.id,
            action="update", payload=_payload_json(payload), admin=current_user,
        )
        db.commit()
        refreshed = _require_link(db, entity_type, entity_id, link_id)
        result = serialize_link(db, refreshed, entity_type, entity_id)
        if result is None:
            raise LocalizedHTTPException(status_code=500, message="关联更新失败")
        return result

    proposal_service.submit(
        db, entity_type="entity_quantity_link", entity_id=link.id,
        action="update", payload=_payload_json(payload), proposer=current_user,
    )
    db.commit()
    result = serialize_link(db, link, entity_type, entity_id, pending=True)
    if result is None:
        raise LocalizedHTTPException(status_code=500, message="关联更新失败")
    return result


@router.delete("/entities/{entity_type}/{entity_id}/quantity-links/{link_id}")
def delete_quantity_link(
    entity_type: str,
    entity_id: int,
    link_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_link(db, entity_type, entity_id, link_id)

    if current_user.is_admin:
        proposal_service.apply_as_admin(
            db, entity_type="entity_quantity_link", entity_id=link_id,
            action="delete", payload={}, admin=current_user,
        )
        db.commit()
        return {
            "message": api_message(request, "关联已删除"),
            "pending": False,
        }

    proposal_service.submit(
        db, entity_type="entity_quantity_link", entity_id=link_id,
        action="delete", payload={}, proposer=current_user,
    )
    db.commit()
    return {
        "message": api_message(request, "删除关联的申请已提交，等待审核"),
        "pending": True,
    }
