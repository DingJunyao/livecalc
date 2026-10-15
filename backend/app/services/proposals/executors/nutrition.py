"""营养数据执行器：补空自动 / 覆盖审核。

policy 在 apply 内动态 set（补空 → auto_approve；覆盖 → manual）。
更稳妥的做法是在 service.submit 前置检查决定 policy，本期以执行器内 set_policy 示意。

payload 期望：{"nutrients": {...}, "base_quantity": 100, "base_unit": "g"}
entity_id：食材 id（NutritionData.ingredient_id）

base_quantity/base_unit 即「每 X 单位」的营养基准，写入 NutritionData 的
reference_amount/reference_unit（缺省仍为 100 g）。base_unit 可以是全局单位
缩写（g/mL/斤…）或该原料自定义单位的名称（如「袋」，计算时按实体单位覆盖折算）。
"""
from typing import Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.services.proposals.base import ProposalExecutor, ApplyResult
from app.services.proposals.registry import ExecutorRegistry
from app.models.nutrition_data import NutritionData
from app.models.nutrition import Ingredient
from app.core.exceptions import LocalizedHTTPException

# 营养基准单位的最大长度（与 NutritionData.reference_unit 列宽一致）
MAX_BASE_UNIT_LENGTH = 50


def parse_base_reference(payload: dict) -> tuple[Optional[float], Optional[str]]:
    """从 payload 解析营养基准 (amount, unit)。

    两者都可缺省（保持列默认 100 g / 现有值）；给定时必须是正数 / 非空字符串，
    否则抛 400 —— 免得把 0 或空串写进基准，让后续缩放除以 0。
    """
    raw_amount = (payload or {}).get("base_quantity")
    raw_unit = (payload or {}).get("base_unit")

    amount: Optional[float] = None
    if raw_amount is not None:
        try:
            amount = float(raw_amount)
        except (TypeError, ValueError):
            raise LocalizedHTTPException(status_code=400, message='base_quantity 必须是数字')
        if amount <= 0:
            raise LocalizedHTTPException(status_code=400, message='base_quantity 必须大于 0')

    unit: Optional[str] = None
    if raw_unit is not None:
        unit = str(raw_unit).strip()
        if not unit:
            raise LocalizedHTTPException(status_code=400, message='base_unit 不能为空')
        if len(unit) > MAX_BASE_UNIT_LENGTH:
            raise LocalizedHTTPException(
                status_code=400,
                message='base_unit 过长（最多 {limit} 字符）',
                limit=MAX_BASE_UNIT_LENGTH,
            )
    return amount, unit


def apply_base_reference(target: NutritionData, amount: Optional[float], unit: Optional[str]) -> None:
    """把解析后的基准写到目标行（None = 保持原值）。"""
    if amount is not None:
        target.reference_amount = amount
    if unit is not None:
        target.reference_unit = unit


class NutritionExecutor(ProposalExecutor):
    entity_type = "nutrition"

    def entity_label(self, db: Session, proposal) -> Optional[str]:
        """entity_id 是 ingredient.id，查 ingredient.name。"""
        eid = proposal.entity_id
        if eid is None:
            return None
        ing = db.query(Ingredient).get(eid)
        return f"原料「{ing.name}」" if ing else None

    def validate(self, db: Session, proposal) -> None:
        eid = proposal.entity_id
        if eid is None:
            raise LocalizedHTTPException(status_code=400, message='营养提议需 entity_id（食材 id）')
        if db.query(Ingredient).get(eid) is None:
            raise LocalizedHTTPException(status_code=404, message='食材 {eid} 不存在', eid=eid)
        if "nutrients" not in (proposal.payload or {}):
            raise LocalizedHTTPException(status_code=400, message='payload 缺少 nutrients')
        parse_base_reference(proposal.payload or {})

    def build_snapshot(self, db: Session, proposal) -> dict:
        """提交时预填 snapshot，供 pending 审核看旧营养数据。"""
        eid = proposal.entity_id
        if eid is None:
            return {}
        existing = db.query(NutritionData).filter(
            NutritionData.ingredient_id == eid).first()
        if existing is not None:
            return {"had_data": True, "nutrients": existing.nutrients,
                    "source": existing.source, "id": existing.id,
                    "reference_amount": existing.reference_amount,
                    "reference_unit": existing.reference_unit}
        return {"had_data": False}

    def preview(self, db: Session, proposal) -> dict:
        eid = proposal.entity_id
        existing = db.query(NutritionData).filter(
            NutritionData.ingredient_id == eid).first()
        return {"ingredient_id": eid, "will_override": existing is not None,
                "note": "覆盖现有数据需审核；补空可自动通过"}

    def apply(self, db: Session, proposal) -> ApplyResult:
        eid = proposal.entity_id
        nutrients = proposal.payload.get("nutrients", {})
        base_amount, base_unit = parse_base_reference(proposal.payload or {})
        existing = db.query(NutritionData).filter(
            NutritionData.ingredient_id == eid).first()

        snapshot = {}
        if existing is not None:
            snapshot = {"had_data": True, "nutrients": existing.nutrients,
                        "source": existing.source, "id": existing.id,
                        "reference_amount": existing.reference_amount,
                        "reference_unit": existing.reference_unit}
        # 写入 / 覆盖
        if existing is None:
            nd = NutritionData(
                ingredient_id=eid, nutrients=nutrients,
                source="custom", is_verified=True)
            apply_base_reference(nd, base_amount, base_unit)
            db.add(nd)
        else:
            existing.nutrients = nutrients
            existing.source = "custom"
            existing.is_verified = True
            apply_base_reference(existing, base_amount, base_unit)

        # 关键：补空 → auto_approve；覆盖 → manual（执行器内动态 set 取巧）
        # 注：submit 在 apply 前已读 policy 决定分流，此处 set 仅影响后续提交；
        #     覆盖场景的「manual」由治理总表默认 policy=manual 兜底，补空由 submit 调用方
        #     （API 层）在提交前判断后传 review_policy 更稳——此处保留示意。
        ExecutorRegistry.set_policy(
            "nutrition", "update",
            "auto_approve" if not snapshot.get("had_data") else "manual")

        return ApplyResult(
            snapshot=snapshot,
            revert_payload={"restore": snapshot} if snapshot else {"delete": True},
            summary="营养数据已更新",
        )

    def revert(self, db: Session, proposal) -> None:
        snap = proposal.snapshot or {}
        rp = proposal.revert_payload or {}
        eid = proposal.entity_id
        if rp.get("delete"):
            db.query(NutritionData).filter(
                NutritionData.ingredient_id == eid).delete(synchronize_session=False)
            return
        if snap.get("had_data"):
            nd = db.query(NutritionData).get(snap["id"])
            if nd is not None:
                nd.nutrients = snap["nutrients"]
                nd.source = snap["source"]
                if "reference_amount" in snap:
                    nd.reference_amount = snap["reference_amount"]
                if "reference_unit" in snap:
                    nd.reference_unit = snap["reference_unit"]
