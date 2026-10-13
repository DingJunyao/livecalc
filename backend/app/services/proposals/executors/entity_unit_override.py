"""实体单位覆盖执行器：CRUD + 软删。

继承 CrudExecutorBase 复用 create/update/delete 默认实现（delete 软删 is_active=False、
revert restore_active 复活）。覆写 validate：
- create：按业务 entity_type+entity_id+unit_name 查重（带 is_active=True 过滤）
- update/delete：校验目标存在且 is_active=True（基类默认按 id 查不带过滤，子类补）

两种 entity_type 区分（关键，勿混）：
- 框架级 entity_type = "entity_unit_override"（本执行器注册名，进 change_proposals.entity_type）
- 业务级 entity_type（"ingredient"/"product"，来自 URL 路径，放 payload，create 时写入数据行）

自定义单位覆盖生效/回滚后，需要按业务实体重算既有价格记录的 standard_quantity
（否则扫码后先记价、后补单位覆盖的记录仍按默认 100g/个 换算），见 _recompute_*。
"""
from typing import Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.services.proposals.executors._crud_base import CrudExecutorBase
from app.models.entity_unit_override import EntityUnitOverride
from app.core.exceptions import LocalizedHTTPException


class EntityUnitOverrideExecutor(CrudExecutorBase):
    entity_type = "entity_unit_override"
    model_class = EntityUnitOverride

    def validate(self, db: Session, proposal) -> None:
        action = proposal.action
        if action == "create":
            p = proposal.payload or {}
            biz_type = p.get("entity_type")
            biz_id = p.get("entity_id")
            unit_name = p.get("unit_name")
            if biz_type is None or biz_id is None or unit_name is None:
                raise LocalizedHTTPException(status_code=400, message='payload 缺少 entity_type/entity_id/unit_name')
            self._validate_weight_unit(db, p)
            self._validate_weight_unit_override(db, p, biz_type, biz_id, None)
            dup = (
                db.query(EntityUnitOverride)
                .filter(
                    EntityUnitOverride.entity_type == biz_type,
                    EntityUnitOverride.entity_id == biz_id,
                    EntityUnitOverride.unit_name == unit_name,
                    EntityUnitOverride.is_active.is_(True),
                )
                .first()
            )
            if dup is not None:
                raise LocalizedHTTPException(status_code=400, message="{biz_type}/{biz_id} 已存在单位覆盖 '{unit_name}'", biz_type=biz_type, biz_id=biz_id, unit_name=unit_name)
            return
        # update/delete：基类 validate 仅按 id 查存在性，这里补 is_active=True 校验
        eid = proposal.entity_id
        if eid is None:
            raise LocalizedHTTPException(status_code=400, message='update/delete 需 entity_id')
        obj = (
            db.query(EntityUnitOverride)
            .filter(
                EntityUnitOverride.id == eid,
                EntityUnitOverride.is_active.is_(True),
            )
            .first()
        )
        if obj is None:
            raise LocalizedHTTPException(status_code=404, message='实体单位覆盖 {eid} 不存在或已删除', eid=eid)
        if action == "update":
            p = proposal.payload or {}
            self._validate_weight_unit(db, p)
            # 与存量值合并后再校验互斥/成环（payload 里不带的字段沿用原值）
            merged = {
                "weight_unit_id": p.get("weight_unit_id", obj.weight_unit_id),
                "weight_unit_override_id": p.get(
                    "weight_unit_override_id", obj.weight_unit_override_id
                ),
            }
            self._validate_weight_unit_override(
                db, merged, obj.entity_type, obj.entity_id, obj.id
            )

    @staticmethod
    def _validate_weight_unit(db: Session, payload: dict) -> None:
        """weight_unit_id（若提供）须指向质量或体积单位。

        覆盖的"每单位量"语义为"1个该单位 = N（g/mL）"，计数等单位无法参与换算。
        """
        wu_id = payload.get("weight_unit_id")
        if wu_id is None:
            return
        from app.models.unit import Unit
        unit = db.query(Unit).filter(Unit.id == wu_id).first()
        if unit is None:
            raise LocalizedHTTPException(status_code=400, message='weight_unit_id {wu_id} 不存在', wu_id=wu_id)
        if unit.unit_type not in ("mass", "volume"):
            raise LocalizedHTTPException(
                status_code=400,
                message='每单位量单位 {name} 须为质量或体积单位',
                name=unit.name,
            )

    @staticmethod
    def _validate_weight_unit_override(
        db: Session, payload: dict, biz_type: str, biz_id: int, self_id: Optional[int]
    ) -> None:
        """weight_unit_override_id（若提供）须指向同一实体的另一个活跃自定义单位，且不能成环。

        嵌套语义：1箱 = 12 盒，盒自身再定义 220 mL。
        """
        ref_id = payload.get("weight_unit_override_id")
        if ref_id is None:
            return
        if payload.get("weight_unit_id") is not None:
            raise LocalizedHTTPException(
                status_code=400,
                message='weight_unit_id 与 weight_unit_override_id 只能设置其一',
            )
        if self_id is not None and int(ref_id) == int(self_id):
            raise LocalizedHTTPException(status_code=400, message='自定义单位不能引用自身')
        ref = (
            db.query(EntityUnitOverride)
            .filter(
                EntityUnitOverride.id == ref_id,
                EntityUnitOverride.is_active.is_(True),
            )
            .first()
        )
        if ref is None:
            raise LocalizedHTTPException(
                status_code=400, message='引用的自定义单位 {ref_id} 不存在', ref_id=ref_id
            )
        if ref.entity_type != biz_type or ref.entity_id != biz_id:
            raise LocalizedHTTPException(
                status_code=400,
                message='只能引用同一实体（{biz_type}/{biz_id}）的自定义单位',
                biz_type=biz_type, biz_id=biz_id,
            )
        # 环检测：沿 weight_unit_override_id 链回溯，若回到 self_id（update 场景）则成环
        seen = {int(ref_id)}
        cursor = ref
        depth = 0
        while cursor is not None and depth < 32:
            nxt = getattr(cursor, "weight_unit_override_id", None)
            if nxt is None:
                return
            if self_id is not None and int(nxt) == int(self_id):
                raise LocalizedHTTPException(
                    status_code=400, message='自定义单位存在循环引用'
                )
            if int(nxt) in seen:
                raise LocalizedHTTPException(
                    status_code=400, message='自定义单位存在循环引用'
                )
            seen.add(int(nxt))
            cursor = (
                db.query(EntityUnitOverride)
                .filter(
                    EntityUnitOverride.id == nxt,
                    EntityUnitOverride.is_active.is_(True),
                )
                .first()
            )
            depth += 1

    def apply(self, db: Session, proposal) -> "ApplyResult":
        """apply 后按业务实体重算价格记录，保证既有记录换算跟随最新覆盖。"""
        result = super().apply(db, proposal)
        self._recompute_price_records(db, proposal)
        return result

    def revert(self, db: Session, proposal) -> None:
        """revert 后同样重算，保证记录换算跟随还原后的覆盖。"""
        super().revert(db, proposal)
        self._recompute_price_records(db, proposal)

    def _recompute_price_records(self, db: Session, proposal) -> None:
        """定位业务实体（product/ingredient）并重算其价格记录。

        create 的 payload 含 entity_type/entity_id；update/delete 的 payload 不含，
        需从覆盖行（proposal.entity_id）回查。重算失败不阻断覆盖生效，仅记录警告
        （可通过 scripts/recompute_price_records.py 兜底修复）。
        """
        from app.services.price_aggregator import (
            recompute_product_standard_quantities,
            recompute_ingredient_standard_quantities,
        )

        p = proposal.payload or {}
        biz_type = p.get("entity_type")
        biz_id = p.get("entity_id")
        if biz_type is None or biz_id is None:
            eid = proposal.entity_id
            if eid is None:
                return
            obj = db.query(EntityUnitOverride).get(eid)
            if obj is None:
                return
            biz_type = obj.entity_type
            biz_id = obj.entity_id
        if biz_type is None or biz_id is None:
            return
        try:
            db.flush()  # 让覆盖变更对后续查询可见
            if biz_type == "product":
                recompute_product_standard_quantities(db, product_id=biz_id)
            elif biz_type == "ingredient":
                recompute_ingredient_standard_quantities(db, ingredient_id=biz_id)
        except Exception as e:  # pragma: no cover - 防御性兜底
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(
                "重算 %s/%s 价格记录失败（覆盖已生效，可稍后修复）: %s", biz_type, biz_id, e
            )

    def entity_label(self, db: Session, proposal) -> Optional[str]:
        """业务实体名（payload.entity_type/entity_id）+ unit_name。

        update/delete 时 entity_id 是 override.id，可补查其 unit_name。
        """
        from app.models.nutrition import Ingredient
        from app.models.product_entity import Product
        p = proposal.payload or {}
        biz_type = p.get("entity_type")
        biz_id = p.get("entity_id")
        unit_name = p.get("unit_name")
        parts = []
        if biz_type and biz_id is not None:
            if biz_type == "ingredient":
                ing = db.query(Ingredient).get(biz_id)
                if ing:
                    parts.append(f"原料「{ing.name}」")
            elif biz_type == "product":
                prod = db.query(Product).get(biz_id)
                if prod:
                    parts.append(f"商品「{prod.name}」")
        # update/delete 时 entity_id 是 override.id，可补查 unit_name
        if not unit_name and proposal.entity_id is not None:
            ov = db.query(EntityUnitOverride).get(proposal.entity_id)
            if ov:
                unit_name = ov.unit_name
        if unit_name:
            parts.append(f"单位「{unit_name}」")
        return " ".join(parts) if parts else None
