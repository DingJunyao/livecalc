# backend/tests/models/test_user_merchant_product_order.py

"""UserMerchantProductOrder 模型 & API 集成测试。"""

import pytest
from datetime import date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.core.security import get_current_user

# 导入所有需要的模型，确保在 create_all 前注册到 Base.metadata
from app.models import (
    User, Merchant, ProductRecord,
)
from app.models.product_entity import Product
from app.models.nutrition import Ingredient
from app.models.unit import Unit
from app.models.user_merchant_product_order import UserMerchantProductOrder

# 内存库 setup — 先 import 模型再 create_all
engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
Base.metadata.create_all(engine)
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class FakeUser:
    id = 1
    username = "testuser"
    email = "test@example.com"
    phone = None
    is_admin = False
    email_verified = True
    created_at = None


def fake_current_user():
    return FakeUser()


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_override():
    """每个测试前后安装/卸载 override。"""
    prev = dict(app.dependency_overrides)
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = fake_current_user
    yield
    app.dependency_overrides.clear()
    app.dependency_overrides.update(prev)


@pytest.fixture()
def db():
    """提供会话并清理所有数据。"""
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
    # 清理所有表
    session = TestingSessionLocal()
    for table in reversed(Base.metadata.sorted_tables):
        session.execute(table.delete())
    session.commit()
    session.close()


@pytest.fixture()
def test_data(db):
    """创建测试用用户、商家、商品。"""
    user = User(id=1, username="testuser", email="test@example.com",
                password_hash="x", is_admin=False)
    ingredient = Ingredient(id=1, name="通用食材")
    merchant = Merchant(id=1, user_id=1, name="测试超市")
    product_a = Product(id=1, name="牛奶", ingredient_id=1)
    product_b = Product(id=2, name="面包", ingredient_id=1)
    product_c = Product(id=3, name="鸡蛋", ingredient_id=1)

    db.add_all([user, ingredient, merchant, product_a, product_b, product_c])
    db.commit()
    return {"merchant_id": 1, "product_ids": [1, 2, 3]}


def _create_price_record(db, uid, mid, pid, price=1.0):
    """辅助：创建一条产品价格记录。"""
    unit = db.query(Unit).filter(Unit.abbreviation == "斤").first()
    if not unit:
        unit = Unit(abbreviation="斤", name="斤", unit_type="mass")
        db.add(unit)
        db.commit()
        db.refresh(unit)
    product = db.query(Product).filter(Product.id == pid).first()
    rec = ProductRecord(
        user_id=uid, merchant_id=mid, product_id=pid,
        product_name=product.name if product else "",
        price=price, original_quantity=1, original_unit_id=unit.id,
        standard_quantity=500, standard_unit_id=unit.id,
        record_type="price",
    )
    db.add(rec)
    db.commit()


class TestSaveProductOrders:
    """测试 POST /api/v1/merchants/{id}/product-orders"""

    def test_save_orders_success(self, db, test_data):
        mid = test_data["merchant_id"]
        pids = test_data["product_ids"]

        resp = client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": pids,
            "session_date": "2026-06-23",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "已保存" in data["message"]

        # 验证数据已写入
        records = db.query(UserMerchantProductOrder).filter(
            UserMerchantProductOrder.merchant_id == mid,
            UserMerchantProductOrder.session_date == date(2026, 6, 23),
        ).order_by(UserMerchantProductOrder.sort_order).all()
        assert len(records) == 3
        assert [r.product_id for r in records] == [1, 2, 3]
        assert [r.sort_order for r in records] == [0, 1, 2]

    def test_save_orders_upsert(self, db, test_data):
        """同一天同商品再次保存：新顺序追加到末尾，sort_order 不碰撞。"""
        mid = test_data["merchant_id"]

        # 第一次保存 [1,2,3] → sort_order 0,1,2
        client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [1, 2, 3],
            "session_date": "2026-06-23",
        })
        # 第二次保存相同商品但顺序不同 → 追加到 3,4,5
        client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [3, 2, 1],
            "session_date": "2026-06-23",
        })

        records = db.query(UserMerchantProductOrder).filter(
            UserMerchantProductOrder.merchant_id == mid,
            UserMerchantProductOrder.session_date == date(2026, 6, 23),
        ).order_by(UserMerchantProductOrder.sort_order).all()
        assert len(records) == 3
        # 按 sort_order 排序后，商品顺序为最近一次填写的顺序 [3, 2, 1]
        assert [r.product_id for r in records] == [3, 2, 1]
        assert [r.sort_order for r in records] == [3, 4, 5]

    def test_save_orders_append_no_collision(self, db, test_data):
        """同一天分批保存不同商品：第二批追加到第一批之后，sort_order 不碰撞。"""
        mid = test_data["merchant_id"]

        client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [1, 2],
            "session_date": "2026-06-23",
        })
        client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [3],
            "session_date": "2026-06-23",
        })

        records = db.query(UserMerchantProductOrder).filter(
            UserMerchantProductOrder.merchant_id == mid,
            UserMerchantProductOrder.session_date == date(2026, 6, 23),
        ).order_by(UserMerchantProductOrder.sort_order).all()
        assert len(records) == 3
        assert [r.product_id for r in records] == [1, 2, 3]
        assert [r.sort_order for r in records] == [0, 1, 2]

    def test_save_orders_invalid_date(self, db, test_data):
        mid = test_data["merchant_id"]
        resp = client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [1, 2],
            "session_date": "2026/06/23",
        })
        assert resp.status_code == 422

    def test_save_orders_merchant_not_found(self, db, test_data):
        resp = client.post("/api/v1/merchants/999/product-orders", json={
            "product_ids": [1, 2],
            "session_date": "2026-06-23",
        })
        assert resp.status_code == 404


class TestFillOrder:
    """测试 GET product-prices 返回 fill_sort_order / fill_session_date。"""

    def test_fill_order_in_response(self, db, test_data):
        """设置了排序记录的商品有 fill_sort_order 与 fill_session_date 字段。"""
        mid = test_data["merchant_id"]

        _create_price_record(db, 1, mid, 1)
        _create_price_record(db, 1, mid, 2)
        _create_price_record(db, 1, mid, 3)

        client.post(f"/api/v1/merchants/{mid}/product-orders", json={
            "product_ids": [2, 1, 3],
            "session_date": "2026-06-23",
        })

        resp = client.get(f"/api/v1/merchants/{mid}/product-prices?limit=10")
        assert resp.status_code == 200
        items = resp.json()["items"]
        filled = [i for i in items if i["fill_sort_order"] is not None]
        assert len(filled) == 3
        # 后端已按填写顺序排序：2, 1, 3
        assert [i["product_id"] for i in items] == [2, 1, 3]
        for i in filled:
            assert i["fill_session_date"] == "2026-06-23"

    def test_no_fill_order_by_default(self, db, test_data):
        """没有排序记录时 fill_sort_order 为 null。"""
        mid = test_data["merchant_id"]
        _create_price_record(db, 1, mid, 1)

        resp = client.get(f"/api/v1/merchants/{mid}/product-prices?limit=10")
        assert resp.status_code == 200
        for item in resp.json()["items"]:
            assert item["fill_sort_order"] is None
            assert item["fill_session_date"] is None


class TestMostRecentSessionOrder:
    """测试按最近填写会话排序。"""

    def test_most_recent_session_wins(self, db, test_data):
        """每个商品取最近一次填写会话的排序号；最近会话的商品排在最前。"""
        mid = test_data["merchant_id"]

        for pid in [1, 2, 3]:
            _create_price_record(db, 1, mid, pid)

        today = date.today()
        yesterday = today - timedelta(days=1)

        orders_data = [
            (1, yesterday, 0), (2, yesterday, 1),   # 昨天: 1→0, 2→1
            (3, today, 0), (1, today, 1),            # 今天: 3→0, 1→1
        ]
        for pid, sess_date, sort_order in orders_data:
            rec = UserMerchantProductOrder(
                user_id=1, merchant_id=mid, product_id=pid,
                session_date=sess_date, sort_order=sort_order,
            )
            db.add(rec)
        db.commit()

        resp = client.get(f"/api/v1/merchants/{mid}/product-prices?limit=10")
        assert resp.status_code == 200
        items = resp.json()["items"]

        # 今天的商品在前（按今天的 sort_order）：3, 1；昨天的在后：2
        assert [i["product_id"] for i in items] == [3, 1, 2]

        item1 = next(i for i in items if i["product_id"] == 1)
        assert item1["fill_session_date"] == today.isoformat()
        assert item1["fill_sort_order"] == 1

        item2 = next(i for i in items if i["product_id"] == 2)
        assert item2["fill_session_date"] == yesterday.isoformat()
        assert item2["fill_sort_order"] == 1
