from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import or_, text
from typing import List, Optional
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.merchant import Merchant
from app.models.map_config import MapConfiguration
from app.services.proposals import service as proposal_service
from app.schemas.merchant import (
    MerchantCreate,
    MerchantUpdate,
    MerchantResponse,
    MerchantCoordinateResponse,
    ProductOrderCreate,
)
from app.models.user_merchant_product_order import UserMerchantProductOrder
from app.models.user_merchant_favorite import UserMerchantFavorite
from app.schemas.common import PaginatedResponse
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.unit import Unit
from app.schemas.product import ProductRecordResponse
from app.models.user import User

from datetime import date as date_type, datetime as _dt
from app.utils.datetime_utils import serialize_datetime

# SQLite 时间字符串格式（UTC naive）：'2026-06-11 03:38:00.000000'
_SQLITE_TS_FMTS = [
    '%Y-%m-%d %H:%M:%S.%f',
    '%Y-%m-%d %H:%M:%S',
]


def _to_iso(value) -> str | None:
    """安全转带时区的 ISO 字符串。

    兼容：
    - datetime 对象 → 直接用 serialize_datetime 加 +00:00
    - SQLite TEXT 时间字符串（naive UTC） → 解析后加 +00:00
    - 其他字符串 → 透传
    """
    if not value:
        return None
    if isinstance(value, _dt):
        return serialize_datetime(value)
    if isinstance(value, str):
        for fmt in _SQLITE_TS_FMTS:
            try:
                dt = _dt.strptime(value, fmt)
                return serialize_datetime(dt)
            except ValueError:
                continue
        # 已经是 ISO 格式或无法识别的字符串，原样返回
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


router = APIRouter()


@router.get("/map-config")
async def get_public_map_config(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取公开的地图配置 - 任何登录用户都可以访问"""
    try:
        config = db.query(MapConfiguration).first()
        if not config:
            # 如果没有配置，返回默认配置（map_enabled 默认 True）
            return {
                "map_enabled": True,
                "available_maps": ["amap", "baidu", "tencent", "tianditu", "osm"],
                "default_map": "amap",
                "map_api_keys": {
                    "amap": None,
                    "amap_security": None,
                    "baidu": None,
                    "tencent": None,
                    "tianditu": {"token": "", "type": "vec"}
                }
            }
        return config.to_dict()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"获取地图配置时发生错误: {str(e)}"
        )


@router.post("", response_model=MerchantResponse)
async def create_merchant(
    merchant: MerchantCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """创建商家"""
    try:
        db_merchant = Merchant(
            user_id=current_user.id,
            name=merchant.name,
            address=merchant.address,
            latitude=merchant.latitude,
            longitude=merchant.longitude,
            is_open=merchant.is_open if merchant.is_open is not None else True
        )
        db.add(db_merchant)
        db.commit()
        db.refresh(db_merchant)
        return db_merchant
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="创建商家时发生错误，请稍后重试"
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="创建商家时发生未知错误"
        )


@router.get("/coordinates", response_model=List[MerchantCoordinateResponse])
async def get_merchant_coordinates(
    search: Optional[str] = Query(None, description="搜索关键词（与列表同语义）"),
    include_closed: bool = Query(False, description="是否包含已关闭的商家"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取商家的坐标全集（不分页，供地图 fitBounds 用）。

    支持与列表同语义的 search / include_closed，保证 fitAll 与列表筛选一致。
    只返回有坐标的商家。商家为共享池，所有登录用户可见全部。
    """
    try:
        query = db.query(Merchant).filter(
            Merchant.latitude.isnot(None),
            Merchant.longitude.isnot(None),
        )
        if not include_closed:
            query = query.filter(Merchant.is_open == True)  # noqa: E712
        if search:
            pattern = f"%{search}%"
            query = query.filter(
                or_(Merchant.name.like(pattern), Merchant.address.like(pattern))
            )
        return [
            {
                "id": m.id,
                "latitude": float(m.latitude),
                "longitude": float(m.longitude),
                "is_open": bool(m.is_open),
            }
            for m in query.all()
        ]
    except SQLAlchemyError:
        raise HTTPException(
            status_code=500,
            detail="获取商家坐标时发生错误，请稍后重试"
        )


# ---------- 收藏端点 ----------
# 注意：收藏端点的固定路径（/favorites、/{id}/favorite）必须注册在
# GET /{merchant_id} 之前，否则 "favorites" 会被当作 merchant_id 路径参数解析。
# FastAPI 按声明顺序匹配路由，这里放在 GET /{merchant_id} 之前。


@router.post("/merge")
async def merge_merchants(
    body: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """合并商家 - 把多个源商家的引用迁到目标商家，软停用源商家。

    分流模式（与 /ingredients/merge 一致）：
    - 管理员：经框架 apply_as_admin 直写（留痕 change_proposals），立即生效。
    - 普通用户：经框架 submit 提议（治理总表 merchant_merge.merge = manual → 待审）。

    payload: {"source_ids": [int], "target_id": int}
    路由顺序：/merge 是固定路径，必须注册在 GET /{merchant_id} 之前，
    否则 "merge" 会被当作 merchant_id 路径参数解析（405/422）。
    """
    source_ids: List[int] = body.get("source_ids") or []
    target_id = body.get("target_id")

    if not source_ids or target_id is None:
        raise HTTPException(status_code=400, detail="缺少必要的参数：source_ids 和 target_id")
    if target_id in source_ids:
        raise HTTPException(status_code=400, detail="目标商家不能同时是源商家")

    payload = {"source_ids": source_ids, "target_id": target_id}

    try:
        if current_user.is_admin:
            proposal_service.apply_as_admin(
                db, entity_type="merchant_merge", entity_id=target_id,
                action="merge", payload=payload, admin=current_user,
            )
            db.commit()
            return {
                "success": True,
                "message": "合并完成（管理员直写）",
                "merged_count": len(source_ids),
            }

        p = proposal_service.submit(
            db, entity_type="merchant_merge", entity_id=target_id,
            action="merge", payload=payload, proposer=current_user,
        )
        db.commit()
        return {
            "success": True,
            "message": f"合并提议已提交（proposal_id={p.id}, status={p.status}）",
            "merged_count": 0,
        }
    except HTTPException:
        raise
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="合并商家时发生错误，请稍后重试"
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="合并商家时发生未知错误"
        )


@router.get("/favorites", response_model=List[MerchantResponse])
async def list_favorite_merchants(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取当前用户收藏的商家列表。

    商家为共享池，收藏表 user_merchant_favorites 表达「我的收藏」。
    """
    try:
        from sqlalchemy import select
        fav_ids_subq = select(UserMerchantFavorite.merchant_id).where(
            UserMerchantFavorite.user_id == current_user.id
        )
        return db.query(Merchant).filter(Merchant.id.in_(fav_ids_subq)).all()
    except SQLAlchemyError:
        raise HTTPException(
            status_code=500,
            detail="获取收藏商家列表时发生错误，请稍后重试"
        )


@router.post("/{merchant_id}/favorite")
async def add_favorite(
    merchant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """收藏一个商家（共享池中的任意商家均可收藏）。"""
    try:
        if not db.query(Merchant).filter(Merchant.id == merchant_id).first():
            raise HTTPException(status_code=404, detail="商家不存在")
        existing = db.query(UserMerchantFavorite).filter(
            UserMerchantFavorite.user_id == current_user.id,
            UserMerchantFavorite.merchant_id == merchant_id,
        ).first()
        if not existing:
            db.add(UserMerchantFavorite(
                user_id=current_user.id, merchant_id=merchant_id
            ))
            db.commit()
        return {"ok": True}
    except HTTPException:
        raise
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="收藏商家时发生错误，请稍后重试"
        )


@router.delete("/{merchant_id}/favorite")
async def remove_favorite(
    merchant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """取消收藏一个商家。"""
    try:
        db.query(UserMerchantFavorite).filter(
            UserMerchantFavorite.user_id == current_user.id,
            UserMerchantFavorite.merchant_id == merchant_id,
        ).delete()
        db.commit()
        return {"ok": True}
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="取消收藏时发生错误，请稍后重试"
        )


@router.get("/{merchant_id}", response_model=MerchantResponse)
async def get_merchant(
    merchant_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取单个商家详情。

    商家为共享池，按 id 查询即可（不再校验 user_id 归属）。
    """
    try:
        merchant = db.query(Merchant).filter(
            Merchant.id == merchant_id
        ).first()
        if not merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        response = MerchantResponse.model_validate(merchant)

        # 非管理员追加 pending_proposal
        if not getattr(current_user, "is_admin", False):
            from app.services.proposals.pending import get_pending_proposal
            pp = get_pending_proposal(db, "merchant", merchant_id, current_user.id)
            if pp:
                response.pending_proposal = {"id": pp.id, "action": pp.action, "payload": pp.payload}

        return response
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="获取商家详情时发生错误"
        )


@router.get("/{merchant_id}/prices", response_model=PaginatedResponse)
async def get_merchant_prices(
    merchant_id: int,
    skip: int = Query(0, ge=0, description="跳过的记录数"),
    limit: int = Query(20, ge=1, le=100, description="每页记录数"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取商家的价格记录列表（分页）。

    商家为共享池（仅校验存在）；价格记录改为跨用户公开（去标识，不含 user_id/record_type）。
    """
    try:
        # 校验商家存在于共享池
        merchant = db.query(Merchant).filter(
            Merchant.id == merchant_id
        ).first()
        if not merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        query = db.query(ProductRecord).options(
            joinedload(ProductRecord.original_unit),
            joinedload(ProductRecord.standard_unit),
            joinedload(ProductRecord.merchant)
        ).filter(
            ProductRecord.merchant_id == merchant_id
        )

        total = query.count()
        records = query.order_by(ProductRecord.recorded_at.desc()).offset(skip).limit(limit).all()

        items = [
            ProductRecordResponse(
                id=record.id,
                product_id=record.product_id,
                product_name=record.product_name,
                merchant_id=record.merchant_id,
                merchant_name=record.merchant.name if record.merchant else None,
                price=record.price,
                currency=record.currency,
                original_quantity=record.original_quantity,
                original_unit=record.original_unit.abbreviation if record.original_unit else "",
                unit_id=record.original_unit_id,
                standard_quantity=record.standard_quantity,
                standard_unit=record.standard_unit.abbreviation if record.standard_unit else "",
                standard_unit_id=record.standard_unit_id,
                record_type=record.record_type,
                exchange_rate=record.exchange_rate,
                recorded_at=record.recorded_at,
                notes=record.notes
            )
            for record in records
        ]

        page = (skip // limit) + 1
        return PaginatedResponse.create(
            items=items,
            total=total,
            page=page,
            page_size=limit
        )
    except HTTPException:
        raise
    except SQLAlchemyError:
        raise HTTPException(
            status_code=500,
            detail="获取商家价格记录时发生错误，请稍后重试"
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="获取商家价格记录时发生未知错误"
        )


@router.get("/{merchant_id}/product-prices")
async def get_merchant_product_prices(
    merchant_id: int,
    skip: int = Query(0, ge=0, description="跳过的记录数"),
    limit: int = Query(20, ge=1, le=500, description="每页记录数"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取商家每个商品的最新价格，价格换算为该商品/原料默认单位的单价。

    商家为共享池（仅校验存在），但价格记录仍按 user_id 隔离（只看自己的记录）。
    """
    from decimal import Decimal
    from app.services.unit_conversion_service import UnitConversionService

    try:
        # 校验商家存在于共享池
        merchant = db.query(Merchant).filter(
            Merchant.id == merchant_id
        ).first()
        if not merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        # 原生 SQL：CTE 取每商品最新价，外层 JOIN 出 standard_unit 缩写与
        # 商品关联原料的默认单位缩写，供 Python 层做单位换算。
        sql = text("""
            WITH latest AS (
                SELECT product_id, price, original_quantity, standard_quantity,
                       standard_unit_id, recorded_at,
                       ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY recorded_at DESC) AS rn
                FROM product_records
                WHERE user_id = :uid AND merchant_id = :mid
            ),
            recent_orders AS (
                SELECT product_id, session_date, sort_order
                FROM (
                    SELECT product_id, session_date, sort_order,
                           ROW_NUMBER() OVER (
                               PARTITION BY product_id
                               ORDER BY session_date DESC, sort_order ASC
                           ) AS orn
                    FROM user_merchant_product_orders
                    WHERE user_id = :uid AND merchant_id = :mid
                ) sub
                WHERE sub.orn = 1
            )
            SELECT l.product_id, l.price, l.original_quantity, l.standard_quantity,
                   l.recorded_at,
                   su.abbreviation AS standard_unit_abbr,
                   su.unit_type     AS standard_unit_type,
                   p.name,
                   ic.id            AS category_id,
                   ic.display_name  AS category_display_name,
                   ic.sort_order    AS category_sort_order,
                   ro.session_date  AS fill_session_date,
                   ro.sort_order    AS fill_sort_order
            FROM latest l
            JOIN units su ON su.id = l.standard_unit_id
            JOIN products p ON p.id = l.product_id
            LEFT JOIN ingredients i ON i.id = p.ingredient_id
            LEFT JOIN ingredient_categories ic ON ic.id = i.category_id
            LEFT JOIN recent_orders ro ON ro.product_id = l.product_id
            WHERE l.rn = 1
            ORDER BY
                (ro.product_id IS NULL) ASC,
                ro.session_date DESC,
                ro.sort_order ASC,
                COALESCE(ic.sort_order, 999999) ASC,
                p.name ASC
            LIMIT :limit OFFSET :skip
        """)

        rows = db.execute(sql, {
            "uid": current_user.id,
            "mid": merchant_id,
            "limit": limit,
            "skip": skip,
        }).fetchall()

        # 去重后的商品总数（用于分页）
        count_sql = text("""
            SELECT COUNT(*) FROM (
                SELECT product_id,
                       ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY recorded_at DESC) AS rn
                FROM product_records
                WHERE user_id = :uid AND merchant_id = :mid
            ) AS subq WHERE rn = 1
        """)
        total = db.execute(count_sql, {"uid": current_user.id, "mid": merchant_id}).scalar() or 0
        unit_service = UnitConversionService(db)
        items = []
        for r in rows:
            price = float(r.price) if r.price else 0
            std_qty = float(r.standard_quantity) if r.standard_quantity else 0

            unit_price = None
            unit_label = None

            # 原料默认单位字段已迁移至用户级偏好，直接按固定参考单位换算（质量->元/斤，体积->元/L）
            if unit_price is None and std_qty > 0:
                if r.standard_unit_type == "mass":
                    unit_price = price / std_qty * 500
                    unit_label = "元 / 斤"
                elif r.standard_unit_type == "volume":
                    unit_price = price / std_qty * 1000
                    unit_label = "元 / L"

            items.append({
                "product_id": r.product_id,
                "product_name": r.name,
                "price": round(price, 2),
                "standard_unit_price": round(unit_price, 2) if unit_price is not None else None,
                "standard_unit_label": unit_label,
                "original_quantity": float(r.original_quantity) if r.original_quantity is not None else 0,
                "recorded_at": _to_iso(r.recorded_at),
                "category_id": r.category_id,
                "category_display_name": r.category_display_name,
                "category_sort_order": r.category_sort_order,
                "fill_sort_order": r.fill_sort_order,
                "fill_session_date": str(r.fill_session_date) if r.fill_session_date else None,
            })

        page = (skip // limit) + 1 if limit else 1
        return PaginatedResponse.create(
            items=items,
            total=total,
            page=page,
            page_size=limit
        )
    except HTTPException:
        raise
    except SQLAlchemyError:
        import traceback as _tb
        _tb.print_exc()
        raise HTTPException(
            status_code=500,
            detail="获取商家商品最新价格时发生错误，请稍后重试"
        )
    except Exception:
        import traceback as _tb
        _tb.print_exc()
        raise HTTPException(
            status_code=500,
            detail="获取商家商品最新价格时发生未知错误"
        )


@router.post("/{merchant_id}/product-orders")
async def save_product_orders(
    merchant_id: int,
    body: ProductOrderCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """保存本次快速填写的商品顺序。

    按 (user_id, merchant_id, product_id, session_date) upsert 每条记录。
    sort_order 取 product_ids 数组的索引（从 0 开始）。
    商家为共享池（仅校验存在），排序记录本身按 user_id 隔离。
    """
    try:
        # 校验商家存在于共享池
        merchant = db.query(Merchant).filter(
            Merchant.id == merchant_id,
        ).first()
        if not merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        # 解析日期
        try:
            sess_date = date_type.fromisoformat(body.session_date)
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="session_date 格式无效，应为 YYYY-MM-DD")

        # 查询当天已有记录（用于 upsert）。
        # 本请求内 (user_id, merchant_id, session_date) 固定，以 product_id 为键即可。
        existing: dict[int, UserMerchantProductOrder] = {
            row.product_id: row
            for row in db.query(UserMerchantProductOrder).filter(
                UserMerchantProductOrder.user_id == current_user.id,
                UserMerchantProductOrder.merchant_id == merchant_id,
                UserMerchantProductOrder.session_date == sess_date,
            ).all()
        }

        # 新批次追加到当天已记录顺序的末尾，避免多次保存时 sort_order 碰撞。
        # 例如先存 [A,B,C] 再存 [D,E]，D、E 应排在 A,B,C 之后（sort_order 3、4）
        # 而非从 0 重新开始——否则与第一批碰撞，导致顺序错乱。
        # 请求体内若出现重复 product_id（如粘贴导入时两行匹配到同一商品），
        # 第二次遇到时更新已有对象的 sort_order（移到末尾），而非再次 db.add。
        next_sort = max((r.sort_order for r in existing.values()), default=-1) + 1
        seen: dict[int, UserMerchantProductOrder] = {}

        for pid in body.product_ids:
            record = seen.get(pid) or existing.get(pid)
            if record is None:
                record = UserMerchantProductOrder(
                    user_id=current_user.id,
                    merchant_id=merchant_id,
                    product_id=pid,
                    session_date=sess_date,
                    sort_order=next_sort,
                )
                db.add(record)
                seen[pid] = record
            else:
                record.sort_order = next_sort
                seen[pid] = record
            next_sort += 1

        db.commit()
        return {"message": f"已保存 {len(body.product_ids)} 条排序记录"}

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"数据库错误: {str(e)}")


@router.put("/{merchant_id}", response_model=MerchantResponse)
async def update_merchant(
    merchant_id: int,
    merchant: MerchantUpdate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """更新商家信息（分流：管理员直写 / 普通用户提议）。

    商家为共享池，原 user_id 过滤已失效（user_id 改 nullable 录入者语义）；
    改用框架分流：管理员 apply_as_admin 直写；普通用户 submit 提议
    （治理总表 merchant.update = manual + high risk → 待审，含坐标高危）。
    """
    try:
        db_merchant = db.query(Merchant).filter(Merchant.id == merchant_id).first()
        if not db_merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        update_data = merchant.model_dump(exclude_unset=True)

        if current_user.is_admin:
            proposal_service.apply_as_admin(
                db, entity_type="merchant", entity_id=merchant_id,
                action="update", payload=update_data, admin=current_user,
            )
            db.commit()
            db.refresh(db_merchant)
            return db_merchant

        p = proposal_service.submit(
            db, entity_type="merchant", entity_id=merchant_id,
            action="update", payload=update_data, proposer=current_user,
        )
        db.commit()
        # merchant.update 治理总表默认 manual → 待审；返回当前商家（值未变）
        return db_merchant
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="更新商家时发生错误，请稍后重试"
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="更新商家时发生未知错误"
        )


@router.delete("/{merchant_id}")
async def delete_merchant(
    merchant_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """删除商家（分流：管理员直写 / 普通用户提议）。

    执行器 delete 为软删（is_open=False + 名称加 [已停用] 前缀），
    并把 ProductRecord.merchant_id 引用置 NULL（不再硬性拒绝有价格的商家）。
    治理总表 merchant.delete = manual + high risk。
    """
    try:
        db_merchant = db.query(Merchant).filter(Merchant.id == merchant_id).first()
        if not db_merchant:
            raise HTTPException(status_code=404, detail="商家不存在")

        if current_user.is_admin:
            proposal_service.apply_as_admin(
                db, entity_type="merchant", entity_id=merchant_id,
                action="delete", payload={}, admin=current_user,
            )
            db.commit()
            return {"message": "商家已停用（管理员直写，价格记录引用已置空）"}

        p = proposal_service.submit(
            db, entity_type="merchant", entity_id=merchant_id,
            action="delete", payload={}, proposer=current_user,
        )
        db.commit()
        return {"message": f"删除提议已提交（proposal_id={p.id}, status={p.status}）"}
    except HTTPException:
        raise
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="删除商家时发生错误，请稍后重试"
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="删除商家时发生未知错误"
        )


@router.get("", response_model=PaginatedResponse[MerchantResponse])
async def get_merchants(
    skip: int = Query(0, ge=0, description="跳过的记录数"),
    limit: int = Query(10, ge=1, le=100, description="每页记录数"),
    search: Optional[str] = Query(None, description="搜索关键词（商家名称或地址）"),
    include_closed: bool = Query(False, description="是否包含已关闭的商家"),
    no_price: bool = Query(False, description="筛选未维护过价格的商家"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """获取商家列表（支持分页和搜索）。

    商家为共享池：所有登录用户可见全部商家（含他人录入的），
    私有归属语义改由 user_merchant_favorites（收藏）表达。
    """
    try:
        # 构建查询（共享池，不再按 user_id 过滤）
        query = db.query(Merchant)

        # 默认只显示营业中的商家
        if not include_closed:
            query = query.filter(Merchant.is_open == True)

        # 添加搜索条件
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Merchant.name.like(search_pattern),
                    Merchant.address.like(search_pattern)
                )
            )

        # 特殊条件：未维护过价格
        if no_price:
            from sqlalchemy import exists
            query = query.filter(
                ~exists().where(ProductRecord.merchant_id == Merchant.id)
            )

        # 获取总数
        total = query.count()

        # 分页查询
        merchants = query.order_by(Merchant.created_at.desc()).offset(skip).limit(limit).all()

        # 计算页码
        page = (skip // limit) + 1

        # 返回分页响应
        return PaginatedResponse.create(
            items=merchants,
            total=total,
            page=page,
            page_size=limit
        )
    except SQLAlchemyError:
        raise HTTPException(
            status_code=500,
            detail="获取商家列表时发生错误，请稍后重试"
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="获取商家列表时发生未知错误"
        )
