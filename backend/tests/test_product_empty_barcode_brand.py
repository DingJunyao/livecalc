"""商品保存时空字符串条码/品牌归一化为 NULL（BUGFIX：保存失败请重试）。

背景：移动端商品表单把留空的条码/品牌以 "" 提交；products.barcode 有唯一约束，
库里一旦存在一条 barcode='' 的历史行，任何其他商品的保存（改名等）都会撞
UNIQUE 约束 → 500 → 移动端只显示「保存失败，请重试」。
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.nutrition import Ingredient
from app.models.product_entity import Product
from app.services.proposals.bootstrap import register_all

client = TestClient(app)


@pytest.fixture(autouse=True)
def _setup():
    register_all()


@pytest.fixture()
def _seed(db_session, as_admin):
    ing = Ingredient(name="空条码回归原料", is_active=True)
    db_session.add(ing)
    db_session.flush()
    dirty = Product(name="历史脏数据商品", ingredient_id=ing.id, barcode="", is_active=True)
    target = Product(name="鹿茸菇", ingredient_id=ing.id, is_active=True)
    db_session.add_all([dirty, target])
    db_session.commit()
    yield dirty.id, target.id
    # 模块级共享内存库：用例结束清场，避免 barcode='' 残留行影响后续用例
    db_session.query(Product).filter(Product.ingredient_id == ing.id).delete()
    db_session.query(Ingredient).filter(Ingredient.id == ing.id).delete()
    db_session.commit()


def test_update_with_empty_barcode_succeeds(db_session, as_admin, _seed):
    dirty_id, target_id = _seed
    resp = client.put(
        f"/api/v1/products/entity/{target_id}",
        json={"name": "鹿茸菇（鲜）", "barcode": "", "brand": ""},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["barcode"] is None
    assert body["brand"] is None


def test_create_with_empty_barcode_succeeds(db_session, as_admin, _seed):
    dirty_id, target_id = _seed
    resp = client.post(
        "/api/v1/products/entity",
        json={"name": "鹿茸菇B", "ingredient_id": target_id, "barcode": "", "brand": ""},
    )
    assert resp.status_code in (200, 201), resp.text
    body = resp.json()
    assert body["barcode"] is None
    assert body["brand"] is None


def test_update_keeps_real_barcode_and_duplicate_check(db_session, as_admin, _seed):
    dirty_id, target_id = _seed
    resp = client.put(
        f"/api/v1/products/entity/{target_id}",
        json={"barcode": "6901234567890"},
    )
    assert resp.status_code == 200, resp.text
    # 真实条码仍查重：与脏数据行 '' 无关，但与其他真实条码冲突要 400
    resp = client.put(
        f"/api/v1/products/entity/{dirty_id}",
        json={"barcode": "6901234567890"},
    )
    assert resp.status_code == 400, resp.text
