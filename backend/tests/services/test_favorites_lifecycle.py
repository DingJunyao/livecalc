"""收藏的生命周期联动：合并搬迁/回滚 + 导出导入往返。"""
import uuid

import pytest

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base
from app.services.proposals.bootstrap import register_all


@pytest.fixture(autouse=True)
def _register_proposal_executors():
    """TestClient 不触发 main.py lifespan，需显式注册提案执行器。"""
    register_all()
    yield


def _seed_two_ingredients(db):
    from app.models.nutrition import Ingredient

    suffix = uuid.uuid4().hex[:10]
    src = Ingredient(name=f"收藏合并源_{suffix}", is_active=True)
    tgt = Ingredient(name=f"收藏合并目标_{suffix}", is_active=True)
    db.add_all([src, tgt])
    db.commit()
    return src.id, tgt.id


def _favorite(db, entity_type, entity_id, user_id=FakeUser.id):
    from app.models.user_favorite import UserFavorite

    db.add(UserFavorite(user_id=user_id, entity_type=entity_type, entity_id=entity_id))
    db.commit()


def _cleanup(ingredient_ids):
    from app.models.nutrition import Ingredient
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.query(UserFavorite).filter(
            UserFavorite.entity_id.in_(list(ingredient_ids))
        ).delete(synchronize_session=False)
        db.query(Ingredient).filter(Ingredient.id.in_(list(ingredient_ids))).delete(
            synchronize_session=False
        )
        db.commit()
    finally:
        db.close()


def test_ingredient_merge_removes_source_favorites(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        src_id, tgt_id = _seed_two_ingredients(db)
        _favorite(db, "ingredient", src_id)
        _favorite(db, "ingredient", tgt_id)
    finally:
        db.close()

    client = TestClient(app)
    try:
        # 管理员直写（apply_as_admin → IngredientExecutor._apply_merge）
        resp = client.post("/api/v1/ingredients/merge", json={
            "source_ingredient_ids": [src_id], "target_ingredient_id": tgt_id,
        })
        assert resp.status_code == 200, resp.text
        db = TestingSessionLocal()
        try:
            from app.models.user_favorite import UserFavorite
            rows = db.query(UserFavorite).filter(
                UserFavorite.entity_type == "ingredient",
                UserFavorite.entity_id.in_([src_id, tgt_id]),
            ).all()
            # 源收藏被删；目标收藏保留
            assert [r.entity_id for r in rows] == [tgt_id]
        finally:
            db.close()
    finally:
        _cleanup([src_id, tgt_id])


def test_export_mine_includes_my_favorites(as_admin):
    """mine 模式导出：我的收藏（原料/商品/菜谱）进入导出集。"""
    import io
    import json
    import zipfile

    from app.services.export.packaging import build_export_zip

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        src_id, tgt_id = _seed_two_ingredients(db)
        _favorite(db, "ingredient", src_id)
        zip_bytes, manifest = build_export_zip(db, FakeUser(), "mine")
    finally:
        db.close()

    try:
        zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
        assert "user_favorites.json" in zf.namelist()
        payload = json.loads(zf.read("user_favorites.json"))
        assert any(
            it.get("entity_type") == "ingredient" and it.get("entity_id") == src_id
            for it in payload
        ), payload
        assert manifest["counts"]["user_favorites"] >= 1
    finally:
        _cleanup([src_id, tgt_id])


def test_export_import_favorites_round_trip(as_admin):
    """导出含两类收藏文件（带名字）；解包后重导入全部跳过（幂等）。"""
    import io
    import json
    import os
    import tempfile
    import zipfile
    from pathlib import Path

    from app.services.export.packaging import build_export_zip
    from app.services.importer.importers.export import ExportImporter
    from app.services.importer.models import DataFile, FileCollection

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        src_id, tgt_id = _seed_two_ingredients(db)
        _favorite(db, "ingredient", src_id)
        # 商家收藏：一并导出（含商家名），用于验证商家收藏补进导出
        from app.models.merchant import Merchant
        from app.models.user_merchant_favorite import UserMerchantFavorite

        merchant = Merchant(name=f"收藏导出商家_{uuid.uuid4().hex[:10]}", user_id=FakeUser.id, is_open=True)
        db.add(merchant)
        db.commit()
        merchant_id = merchant.id
        db.add(UserMerchantFavorite(user_id=FakeUser.id, merchant_id=merchant_id))
        db.commit()
        zip_bytes, _manifest = build_export_zip(db, FakeUser(), "full")
    finally:
        db.close()

    try:
        zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
        names = zf.namelist()
        assert "user_favorites.json" in names
        assert "user_merchant_favorites.json" in names
        payload = json.loads(zf.read("user_favorites.json"))
        hit = [it for it in payload
               if it.get("entity_type") == "ingredient" and it.get("entity_id") == src_id]
        assert hit and hit[0].get("entity_name"), hit  # 带名字（供导入重映射）
        mf_payload = json.loads(zf.read("user_merchant_favorites.json"))
        mf_hit = [it for it in mf_payload if it.get("merchant_id") == merchant_id]
        assert mf_hit and mf_hit[0].get("merchant_name"), mf_payload

        # 解包成 FileCollection 后重导入：实体按名字命中原行，收藏全部跳过
        with tempfile.TemporaryDirectory() as tmp:
            zf.extractall(tmp)
            files = [
                DataFile(
                    relative_path=str(p.relative_to(tmp)).replace(os.sep, "/"),
                    absolute_path=str(p),
                    size=p.stat().st_size,
                )
                for p in sorted(Path(tmp).rglob("*")) if p.is_file()
            ]
            db = TestingSessionLocal()
            try:
                importer = ExportImporter(db, user_id=FakeUser.id, is_admin=True)
                result = importer.import_all(FileCollection(files=files))
                assert result.stats.get("user_favorites", 0) == 0, result.stats
                assert result.stats.get("user_merchant_favorites", 0) == 0, result.stats
            finally:
                db.close()
    finally:
        from app.models.merchant import Merchant
        from app.models.user_merchant_favorite import UserMerchantFavorite

        db = TestingSessionLocal()
        try:
            db.query(UserMerchantFavorite).filter(
                UserMerchantFavorite.merchant_id == merchant_id
            ).delete(synchronize_session=False)
            db.query(Merchant).filter(Merchant.id == merchant_id).delete(
                synchronize_session=False
            )
            db.commit()
        finally:
            db.close()
        _cleanup([src_id, tgt_id])
