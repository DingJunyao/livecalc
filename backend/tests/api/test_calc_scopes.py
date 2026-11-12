"""自定义计算范围（多地区组合）API 测试。

覆盖：
  - /api/v1/calc-scopes CRUD：创建/列表/更新/删除、归属 404、校验 400（空地区、
    未知地区、同名、空名、数量上限）
  - PATCH /api/v1/auth/me 的 default_calc_scope_id：归属校验、与 default_calc_scope
    互斥写入（设一方清另一方）
  - 删除范围后 users.default_calc_scope_id 引用清空
  - X-Region 多 id 头（逗号分隔）端到端：/products/entity 最新价按子树并集过滤
"""
from datetime import datetime

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models import (
    AdministrativeRegion,
    Ingredient,
    Merchant,
    Product,
    ProductRecord,
    Unit,
    User,
    UserCalcScope,
)

client = TestClient(app)

# 本文件专用地区树（id 段 7000xx，与其他测试隔离；path 段 = code）
_REGION_TREE = [
    (700001, "TCN2", "多地区测试国", 0, "TCN2", None),
    (700011, "TCN2P1", "多地区测试省A", 1, "TCN2/TCN2P1", 700001),
    (700012, "TCN2P1C1", "多地区测试市A", 2, "TCN2/TCN2P1/TCN2P1C1", 700011),
    (700013, "TCN2P1C1D1", "多地区测试县A", 3, "TCN2/TCN2P1/TCN2P1C1/TCN2P1C1D1", 700012),
    (700021, "TCN2P2", "多地区测试省B", 1, "TCN2/TCN2P2", 700001),
    (700022, "TCN2P2C1", "多地区测试市B", 2, "TCN2/TCN2P2/TCN2P2C1", 700021),
    (700023, "TCN2P2C1D1", "多地区测试县B", 3, "TCN2/TCN2P2/TCN2P2C1/TCN2P2C1D1", 700022),
    (700031, "TCN2P3", "多地区测试省C", 1, "TCN2/TCN2P3", 700001),
    (700032, "TCN2P3C1", "多地区测试市C", 2, "TCN2/TCN2P3/TCN2P3C1", 700031),
]


def _seed_regions(db):
    for rid, code, name, level, path, parent in _REGION_TREE:
        exists = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == rid).first()
        if not exists:
            db.add(AdministrativeRegion(
                id=rid, code=code, name=name, level=level,
                iso_country="CN", path=path, parent_id=parent, is_active=True,
            ))
    db.commit()


def _ensure_user(db, id_=1):
    u = db.query(User).filter(User.id == id_).first()
    if not u:
        u = User(id=id_, username=f"u{id_}", email=f"u{id_}@t.c", password_hash="x")
        db.add(u)
        db.commit()


@pytest.fixture()
def seeded_db(db_session):
    _seed_regions(db_session)
    _ensure_user(db_session, 1)
    _ensure_user(db_session, 2)
    try:
        yield db_session
    finally:
        db_session.query(UserCalcScope).filter(
            UserCalcScope.user_id.in_([1, 2])
        ).delete(synchronize_session=False)
        db_session.query(User).filter(User.default_calc_scope_id.isnot(None)).update(
            {User.default_calc_scope_id: None}, synchronize_session=False
        )
        db_session.query(AdministrativeRegion).filter(
            AdministrativeRegion.id.in_([r[0] for r in _REGION_TREE])
        ).delete(synchronize_session=False)
        db_session.commit()


# ---- CRUD ----

def test_scope_crud_flow(seeded_db, as_admin):
    r = client.post("/api/v1/calc-scopes", json={
        "name": "  老家周边  ",
        "region_ids": [700012, 700022, 700012],
    })
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["name"] == "老家周边"  # strip
    assert body["region_ids"] == [700012, 700022]  # 去重保序
    assert body["is_default"] is False
    assert [g["id"] for g in body["regions"]] == [700012, 700022]
    assert body["regions"][0]["display_name"]
    scope_id = body["id"]

    # 列表可见
    r = client.get("/api/v1/calc-scopes")
    assert r.status_code == 200
    assert [s["id"] for s in r.json()] == [scope_id]

    # 更新：改名 + 换地区
    r = client.put(f"/api/v1/calc-scopes/{scope_id}", json={
        "name": "两地组合", "region_ids": [700013, 700032],
    })
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "两地组合"
    assert r.json()["region_ids"] == [700013, 700032]

    # 删除
    r = client.delete(f"/api/v1/calc-scopes/{scope_id}")
    assert r.status_code == 200
    assert client.get("/api/v1/calc-scopes").json() == []


def test_scope_validation_errors(seeded_db, as_admin):
    # 空地区列表
    assert client.post("/api/v1/calc-scopes", json={"name": "a", "region_ids": []}).status_code == 400
    # 未知地区
    assert client.post("/api/v1/calc-scopes", json={"name": "a", "region_ids": [999999]}).status_code == 400
    # 纯空白名
    assert client.post("/api/v1/calc-scopes", json={"name": "  ", "region_ids": [700012]}).status_code == 400
    # 超过单范围地区数上限（上限校验在存在性校验前，51 个即拒）
    assert client.post(
        "/api/v1/calc-scopes",
        json={"name": "a", "region_ids": list(range(1, 52))},
    ).status_code == 400

    # 同名拒绝；改名撞其他同名也拒绝；改回自己原名放行（排除自己）
    r = client.post("/api/v1/calc-scopes", json={"name": "组合", "region_ids": [700012]})
    assert r.status_code == 201
    scope_id = r.json()["id"]
    assert client.post("/api/v1/calc-scopes", json={"name": "组合", "region_ids": [700022]}).status_code == 400
    other = client.post("/api/v1/calc-scopes", json={"name": "另一个", "region_ids": [700022]})
    assert client.put(
        f"/api/v1/calc-scopes/{other.json()['id']}", json={"name": "组合"}
    ).status_code == 400
    assert client.put(f"/api/v1/calc-scopes/{scope_id}", json={"name": "组合"}).status_code == 200

    # 每用户数量上限：直接插满 20 个后 POST 拒绝
    db = seeded_db
    for i in range(19):  # 已有 2 个（组合/另一个）
        db.add(UserCalcScope(user_id=1, name=f"批量{i:02d}", region_ids=[700012]))
    db.commit()
    assert client.post("/api/v1/calc-scopes", json={"name": "第21个", "region_ids": [700012]}).status_code == 400


def test_scope_ownership_non_admin(seeded_db, as_non_admin):
    # user 1 直接建范围（不经客户端，避免切身份）
    scope = UserCalcScope(user_id=1, name="仅我可见", region_ids=[700012])
    seeded_db.add(scope)
    seeded_db.commit()

    # as_non_admin 生效期间：user 2 访问 user 1 的范围 → 404；列表看不到别人的
    assert client.put(f"/api/v1/calc-scopes/{scope.id}", json={"name": "偷改"}).status_code == 404
    assert client.delete(f"/api/v1/calc-scopes/{scope.id}").status_code == 404
    assert client.get("/api/v1/calc-scopes").json() == []

    # user 2 建自己的范围成功
    r2 = client.post("/api/v1/calc-scopes", json={"name": "非管理员的", "region_ids": [700022]})
    assert r2.status_code == 201


# ---- PATCH /me 互斥与删除清引用 ----

def test_patch_me_default_scope_mutual_exclusion(seeded_db, as_admin):
    r = client.post("/api/v1/calc-scopes", json={"name": "默认组合", "region_ids": [700012, 700022]})
    assert r.status_code == 201
    scope_id = r.json()["id"]

    # 先设层级档位
    r = client.patch("/api/v1/auth/me", json={"default_calc_scope": "province"})
    assert r.status_code == 200, r.text
    assert r.json()["default_calc_scope"] == "province"
    assert r.json()["default_calc_scope_id"] is None

    # 设自定义范围 → 清层级档位
    r = client.patch("/api/v1/auth/me", json={"default_calc_scope_id": scope_id})
    assert r.status_code == 200, r.text
    assert r.json()["default_calc_scope_id"] == scope_id
    assert r.json()["default_calc_scope"] is None

    # 再设回层级档位（含空串=全部地区）→ 清自定义范围
    r = client.patch("/api/v1/auth/me", json={"default_calc_scope": ""})
    assert r.status_code == 200
    assert r.json()["default_calc_scope_id"] is None
    assert r.json()["default_calc_scope"] == ""


def test_patch_me_default_scope_invalid_id(seeded_db, as_admin):
    # 不存在的范围 → 400（归属校验）
    r = client.patch("/api/v1/auth/me", json={"default_calc_scope_id": 999999})
    assert r.status_code == 400


def test_patch_me_rejects_other_users_scope(seeded_db, as_admin):
    # user 2 的范围（直插 DB），user 1 不能把它设为自己的默认
    other_scope = UserCalcScope(user_id=2, name="别人的范围", region_ids=[700022])
    seeded_db.add(other_scope)
    seeded_db.commit()

    r = client.patch("/api/v1/auth/me", json={"default_calc_scope_id": other_scope.id})
    assert r.status_code == 400


def test_delete_scope_clears_default_reference(seeded_db, as_admin):
    r = client.post("/api/v1/calc-scopes", json={"name": "将被删除", "region_ids": [700012]})
    scope_id = r.json()["id"]
    assert client.patch("/api/v1/auth/me", json={"default_calc_scope_id": scope_id}).status_code == 200

    assert client.delete(f"/api/v1/calc-scopes/{scope_id}").status_code == 200
    # GET /auth/me 与 FakeUser 不兼容（既有行为），这里直接断言 DB 状态
    seeded_db.expire_all()
    user = seeded_db.query(User).filter(User.id == 1).first()
    assert user.default_calc_scope_id is None


# ---- X-Region 多 id 头端到端（/products/entity 最新价按子树并集）----

def _build_price_data(db):
    jin = db.query(Unit).filter(Unit.abbreviation == "斤").first()
    if not jin:
        jin = Unit(name="斤", abbreviation="斤", unit_type="mass", si_factor=0.5)
        db.add(jin)
        db.commit()
        db.refresh(jin)

    ing = Ingredient(name="多地区组合测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)
    p = Product(name="多地区组合测试商品", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add(p)
    db.commit()
    db.refresh(p)

    m_a = Merchant(user_id=1, name="组合测试商家A", is_open=True, region_id=700013)  # 市A下县A
    m_b = Merchant(user_id=1, name="组合测试商家B", is_open=True, region_id=700023)  # 市B下县B
    m_c = Merchant(user_id=1, name="组合测试商家C", is_open=True, region_id=700032)  # 市C（范围外）
    db.add_all([m_a, m_b, m_c])
    db.commit()
    for m in (m_a, m_b, m_c):
        db.refresh(m)

    def rec(merchant, price, when):
        db.add(ProductRecord(
            user_id=1, product_id=p.id, product_name=p.name,
            merchant_id=merchant.id, price=price, currency="CNY", user_currency="CNY",
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=500, standard_unit_id=jin.id,
            record_type="price", recorded_at=when,
        ))

    rec(m_a, 3.0, datetime(2026, 6, 17, 3, 20))
    rec(m_b, 5.0, datetime(2026, 6, 20, 8, 0))
    rec(m_c, 10.0, datetime(2026, 7, 29, 11, 42))
    db.commit()
    return {
        "product_id": p.id,
        "ingredient_id": ing.id,
        "merchant_ids": [m_a.id, m_b.id, m_c.id],
    }


@pytest.fixture()
def price_data(seeded_db):
    ids = _build_price_data(seeded_db)
    yield ids
    db = seeded_db
    db.query(ProductRecord).filter(ProductRecord.product_id == ids["product_id"]).delete(synchronize_session=False)
    db.query(Product).filter(Product.id == ids["product_id"]).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ids["ingredient_id"]).delete(synchronize_session=False)
    db.query(Merchant).filter(Merchant.id.in_(ids["merchant_ids"])).delete(synchronize_session=False)
    db.commit()


def test_x_region_multi_id_union(price_data, as_admin):
    url = f"/api/v1/products/entity/{price_data['product_id']}"

    # 组合（市A + 市B）：并集内最新价 = 5.0（市B 的记录更新）
    r = client.get(url, headers={"X-Region": "700012,700022"})
    assert r.status_code == 200, r.text
    assert r.json()["latest_price"] == 5.0

    # 单 id 兼容：只看市A → 3.0
    r = client.get(url, headers={"X-Region": "700012"})
    assert r.status_code == 200
    assert r.json()["latest_price"] == 3.0

    # 嵌套组合（市A + 其下县A）：去重后等价于市A → 3.0
    r = client.get(url, headers={"X-Region": "700012,700013"})
    assert r.status_code == 200
    assert r.json()["latest_price"] == 3.0

    # 非法与未知
    assert client.get(url, headers={"X-Region": "700012,abc"}).status_code == 400
    assert client.get(url, headers={"X-Region": "700012,999999"}).status_code == 400
    # 超过 20 个 id
    assert client.get(url, headers={"X-Region": ",".join(["1"] * 21)}).status_code == 400
