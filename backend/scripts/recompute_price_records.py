"""重算价格记录的 standard_quantity / standard_unit_id（按当前实体单位覆盖）。

背景：扫码新增商品 → 先记价格（计数单位按默认 100g/个 落库）→ 后补自定义单位
（如「袋=1000g」）。单位覆盖变更现在会自动重算（见 EntityUnitOverrideExecutor），
本脚本用于修复历史脏数据或全量对账。

用法（在 backend 目录下执行）：
    python scripts/recompute_price_records.py                 # 全量重算所有商品
    python scripts/recompute_price_records.py --product 1014 1013   # 指定商品
    python scripts/recompute_price_records.py --ingredient 391       # 指定原料（含其下商品）
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.core.database import SessionLocal  # noqa: E402
from app.services.price_aggregator import (  # noqa: E402
    recompute_ingredient_standard_quantities,
    recompute_product_standard_quantities,
)
from app.models.product_entity import Product  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="按当前实体单位覆盖重算价格记录 standard_quantity")
    parser.add_argument("--product", nargs="*", type=int, default=None, help="商品ID列表")
    parser.add_argument("--ingredient", nargs="*", type=int, default=None, help="原料ID列表（重算其下所有商品）")
    args = parser.parse_args()

    db = SessionLocal()
    total = 0
    try:
        if args.product:
            for pid in args.product:
                total += recompute_product_standard_quantities(db, product_id=pid)
        elif args.ingredient:
            for iid in args.ingredient:
                total += recompute_ingredient_standard_quantities(db, ingredient_id=iid)
        else:
            products = (
                db.query(Product)
                .filter(Product.is_active == True)  # noqa: E712
                .all()
            )
            for p in products:
                total += recompute_product_standard_quantities(db, product_id=p.id)
        db.commit()
    finally:
        db.close()
    print(f"done: {total} 条价格记录已按当前覆盖重算")


if __name__ == "__main__":
    main()
