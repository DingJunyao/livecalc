"""商品/原料数量关联提议执行器。

create/update/delete 均走既有 CRUD 基类（软删 + 快照回滚），
apply/revert 后沿关联重算受影响商品/原料的价格记录折克。
"""
from typing import Optional

from sqlalchemy.orm import Session

from app.core.exceptions import LocalizedHTTPException
from app.models.entity_quantity_link import EntityQuantityLink
from app.services.entity_link_service import (
    entity_display_name,
    format_link_sentence,
    normalize_link,
    recompute_links_affected,
    validate_link_payload,
)
from app.services.proposals.base import ApplyResult
from app.services.proposals.executors._crud_base import CrudExecutorBase


class EntityQuantityLinkExecutor(CrudExecutorBase):
    entity_type = "entity_quantity_link"
    model_class = EntityQuantityLink

    # ------------------------------------------------------------------ #
    #  校验
    # ------------------------------------------------------------------ #
    def validate(self, db: Session, proposal) -> None:
        action = proposal.action
        if action == "create":
            data = validate_link_payload(db, proposal.payload or {})
            proposal.payload = {
                "from_type": data["from_type"],
                "from_id": data["from_id"],
                "from_quantity": str(data["from_quantity"]),
                "from_unit": data["from_unit"],
                "to_type": data["to_type"],
                "to_id": data["to_id"],
                "to_quantity": str(data["to_quantity"]),
                "to_unit": data["to_unit"],
                "note": data["note"],
            }
            return

        eid = proposal.entity_id
        if eid is None:
            raise LocalizedHTTPException(status_code=400, message="update/delete 需 entity_id")
        link = (
            db.query(EntityQuantityLink)
            .filter(
                EntityQuantityLink.id == eid,
                EntityQuantityLink.is_active.is_(True),
            )
            .first()
        )
        if link is None:
            raise LocalizedHTTPException(status_code=404, message="关联不存在或已删除")

        if action == "update":
            payload = proposal.payload or {}
            merged = {
                "from_type": link.from_type,
                "from_id": link.from_id,
                "from_quantity": payload.get("from_quantity", link.from_quantity),
                "from_unit": payload.get("from_unit", link.from_unit),
                "to_type": link.to_type,
                "to_id": link.to_id,
                "to_quantity": payload.get("to_quantity", link.to_quantity),
                "to_unit": payload.get("to_unit", link.to_unit),
                "note": payload.get("note", link.note),
            }
            data = validate_link_payload(db, merged, exclude_id=link.id)
            proposal.payload = {
                "from_quantity": str(data["from_quantity"]),
                "from_unit": data["from_unit"],
                "to_quantity": str(data["to_quantity"]),
                "to_unit": data["to_unit"],
                "note": data["note"],
            }
        elif action != "delete":
            raise LocalizedHTTPException(status_code=400, message="不支持的关联操作：{action}", action=action)

    # ------------------------------------------------------------------ #
    #  预览 / 标签
    # ------------------------------------------------------------------ #
    def build_snapshot(self, db: Session, proposal) -> dict:
        return super().build_snapshot(db, proposal)

    def preview(self, db: Session, proposal) -> dict:
        link = self._link_from_proposal(db, proposal)
        sentence = self._sentence(db, link) if link else None
        return {
            "link_id": proposal.entity_id,
            "sentence": sentence,
            "action": proposal.action,
        }

    def entity_label(self, db: Session, proposal) -> Optional[str]:
        link = self._link_from_proposal(db, proposal)
        if link is not None:
            return self._sentence(db, link)
        payload = proposal.payload or {}
        from_name = entity_display_name(
            db, payload.get("from_type"), payload.get("from_id"),
        )
        to_name = entity_display_name(
            db, payload.get("to_type"), payload.get("to_id"),
        )
        if from_name and to_name:
            return format_link_sentence(
                from_name, payload.get("from_quantity", 1), payload.get("from_unit", ""),
                to_name, payload.get("to_quantity", 1), payload.get("to_unit", ""),
            )
        return "商品/原料关联"

    # ------------------------------------------------------------------ #
    #  执行
    # ------------------------------------------------------------------ #
    def apply(self, db: Session, proposal) -> ApplyResult:
        if proposal.action == "create":
            data = validate_link_payload(db, proposal.payload or {})
            obj = EntityQuantityLink(
                **data,
                created_by=proposal.proposer_id,
                updated_by=proposal.proposer_id,
                is_active=True,
            )
            db.add(obj)
            db.flush()
            proposal.entity_id = obj.id
            result = ApplyResult(
                snapshot={},
                revert_payload={
                    "delete_id": obj.id,
                    "seeds": [[obj.from_type, obj.from_id], [obj.to_type, obj.to_id]],
                },
                summary=f"已创建关联：{self._sentence(db, obj)}",
            )
        else:
            result = super().apply(db, proposal)

        link = self._link_from_proposal(db, proposal)
        if link is not None:
            recompute_links_affected(
                db, [(link.from_type, link.from_id), (link.to_type, link.to_id)],
            )
        return result

    def revert(self, db: Session, proposal) -> None:
        seeds = (proposal.revert_payload or {}).get("seeds") or []
        link = self._link_from_proposal(db, proposal, allow_inactive=True)
        if link is not None:
            seeds = [[link.from_type, link.from_id], [link.to_type, link.to_id]]
        super().revert(db, proposal)
        if seeds:
            recompute_links_affected(db, [tuple(s) for s in seeds])

    # ------------------------------------------------------------------ #
    #  内部
    # ------------------------------------------------------------------ #
    @staticmethod
    def _link_from_proposal(
        db: Session,
        proposal,
        *,
        allow_inactive: bool = False,
    ) -> Optional[EntityQuantityLink]:
        eid = proposal.entity_id
        if eid is None:
            return None
        query = db.query(EntityQuantityLink).filter(EntityQuantityLink.id == eid)
        if not allow_inactive:
            query = query.filter(EntityQuantityLink.is_active.is_(True))
        return query.first()

    @staticmethod
    def _sentence(db: Session, link: EntityQuantityLink) -> str:
        from_name = entity_display_name(db, link.from_type, link.from_id)
        to_name = entity_display_name(db, link.to_type, link.to_id)
        return format_link_sentence(
            from_name, link.from_quantity, link.from_unit,
            to_name, link.to_quantity, link.to_unit,
        )
