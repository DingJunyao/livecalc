"""商品执行器：CRUD + 软删（delete 级联 ProductRecord，revert 反级联复活）。

继承 CrudExecutorBase：update 吃基类 setattr；delete 覆写——
唯一商品检查（原料的唯一活跃商品拒删）+ 软删 Product + 级联软删其 ProductRecord +
snapshot；revert 按 snapshot 反级联复活 Product + ProductRecord。

payload 期望（update）：商品基本信息字段（name/brand/barcode/ingredient_id/tags/aliases/updated_by）。
entity_id：Product.id。
"""
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.services.proposals.base import ApplyResult
from app.services.proposals.executors._crud_base import CrudExecutorBase, _json_safe
from app.models.product_entity import Product
from app.models.product import ProductRecord
from app.core.exceptions import LocalizedHTTPException


class ProductExecutor(CrudExecutorBase):
    entity_type = "product"
    model_class = Product

    def validate(self, db: Session, proposal) -> None:
        action = proposal.action
        if action == "create":
            return  # 商品 create 不在本次范围
        eid = proposal.entity_id
        if eid is None:
            raise LocalizedHTTPException(status_code=400, message='update/delete 需 entity_id')
        obj = (
            db.query(Product)
            .filter(Product.id == eid, Product.is_active.is_(True))
            .first()
        )
        if obj is None:
            raise LocalizedHTTPException(status_code=404, message='商品 {eid} 不存在或已删除', eid=eid)

    def build_snapshot(self, db: Session, proposal) -> dict:
        """覆写：delete 动作额外附带级联价格记录数量（供审核台展示影响范围）。"""
        snap = super().build_snapshot(db, proposal)
        if proposal.action == "delete":
            eid = proposal.entity_id
            if eid is not None:
                record_count = (
                    db.query(ProductRecord)
                    .filter(ProductRecord.product_id == eid)
                    .count()
                )
                snap["cascade_record_count"] = record_count
        return snap

    def apply(self, db: Session, proposal) -> ApplyResult:
        if proposal.action == "delete":
            return self._apply_delete(db, proposal)
        result = super().apply(db, proposal)
        if proposal.action == "update":
            self._sync_record_names(db, proposal, result)
        return result

    def _sync_record_names(self, db: Session, proposal, result: ApplyResult) -> None:
        """商品改名时同步其价格记录的 product_name 快照列。

        product_records.product_name 是写入时快照（NOT NULL），价格列表/详情/历史/
        商家价格都直接读它；不同步的话改名后价格信息里仍是旧名。
        只记录"改名前后确实不同"的行，供 revert 逐行还原（通常为空或很小）。
        """
        new_name = (proposal.payload or {}).get("name")
        eid = proposal.entity_id
        if not new_name or eid is None:
            return
        rows = (
            db.query(ProductRecord.id, ProductRecord.product_name)
            .filter(ProductRecord.product_id == eid)
            .all()
        )
        restore = {
            str(row.id): row.product_name
            for row in rows
            if row.product_name != new_name
        }
        if not restore:
            return
        db.query(ProductRecord).filter(
            ProductRecord.id.in_([int(i) for i in restore])
        ).update({ProductRecord.product_name: new_name}, synchronize_session=False)
        result.revert_payload["record_name_restore"] = restore

    def _apply_delete(self, db: Session, proposal) -> ApplyResult:
        eid = proposal.entity_id
        obj = (
            db.query(Product)
            .filter(Product.id == eid, Product.is_active.is_(True))
            .first()
        )
        if obj is None:
            raise LocalizedHTTPException(status_code=404, message='商品 {eid} 不存在或已删除', eid=eid)

        # 唯一商品检查：原料的唯一活跃商品不能删（双层检查之执行器侧）
        sibling_count = (
            db.query(Product)
            .filter(
                Product.ingredient_id == obj.ingredient_id,
                Product.is_active.is_(True),
                Product.id != eid,
            )
            .count()
        )
        if sibling_count == 0:
            raise LocalizedHTTPException(status_code=400, message='「{name}」是其所属原料的唯一商品，无法删除。请先为该原料添加其他商品后再删除。', name=obj.name)

        # snapshot 级联 ProductRecord id（供 revert 复活）
        record_ids = [
            r.id
            for r in db.query(ProductRecord)
            .filter(ProductRecord.product_id == eid)
            .all()
        ]

        # 主记录全列快照（**必须在置 is_active=False 之前**，对齐基类 _crud_base.py:81 顺序）
        snapshot = {c.name: _json_safe(getattr(obj, c.name)) for c in obj.__table__.columns}
        snapshot["_cascade_record_ids"] = record_ids
        snapshot["cascade_record_count"] = len(record_ids)

        # 软删 Product + 级联软删 ProductRecord
        obj.is_active = False
        if record_ids:
            db.query(ProductRecord).filter(
                ProductRecord.product_id == eid
            ).update({"is_active": False}, synchronize_session=False)

        return ApplyResult(
            snapshot=snapshot,
            revert_payload={"restore_active": True, "cascade_record_ids": record_ids},
            summary=f"已软删商品 {eid}（级联 {len(record_ids)} 条价格记录）",
        )

    def revert(self, db: Session, proposal) -> None:
        if proposal.action != "delete":
            super().revert(db, proposal)
            # 还原改名同步过的价格记录名（逐行旧值）
            restore = (proposal.revert_payload or {}).get("record_name_restore") or {}
            for record_id, old_name in restore.items():
                db.query(ProductRecord).filter(
                    ProductRecord.id == int(record_id)
                ).update(
                    {ProductRecord.product_name: old_name},
                    synchronize_session=False,
                )
            return
        rp = proposal.revert_payload or {}
        eid = proposal.entity_id
        obj = db.query(Product).get(eid) if eid else None
        if obj is not None:
            obj.is_active = True
        # 反级联：复活 ProductRecord
        cascade_ids = rp.get("cascade_record_ids") or []
        if cascade_ids:
            db.query(ProductRecord).filter(
                ProductRecord.id.in_(cascade_ids)
            ).update({"is_active": True}, synchronize_session=False)
