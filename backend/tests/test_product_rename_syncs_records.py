"""商品改名/合并时价格记录快照列 product_name 的同步与还原。

背景：product_records.product_name 是写入时快照（NOT NULL），价格列表/详情/
历史/商家价格都直接读它；改商品名不同步会让价格信息里长期显示旧名。
"""
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.unit import Unit
from app.models.nutrition import Ingredient
from app.models.product_entity import Product
from app.models.product import ProductRecord
from app.services.proposals.bootstrap import register_all
from app.services.proposals.executors.product import ProductExecutor

client = TestClient(app)


def _seed(db_session, record_names):
    """建 1 个原料 + 1 个商品 + N 条价格记录（product_name 按传入值）。

    共用 conftest 的模块级内存库，单位/实体跨用例复用（单位缩写唯一）。
    返回 (product_id, [record_id...])。
    """
    kg = db_session.query(Unit).filter(Unit.abbreviation == "kg").first()
    if kg is None:
        kg = Unit(name="千克", abbreviation="kg", unit_type="mass",
                  si_factor=Decimal("1"), is_si_base=True, unit_system="metric")
        db_session.add(kg)
        db_session.flush()
    ing = Ingredient(name="测试原料_改名", is_active=True)
    db_session.add(ing)
    db_session.flush()
    product = Product(name="旧商品名", ingredient_id=ing.id, is_active=True)
    db_session.add(product)
    db_session.flush()
    ids = []
    for name in record_names:
        rec = ProductRecord(
            user_id=1, product_id=product.id, product_name=name,
            price=Decimal("9.9"), original_quantity=Decimal("1"),
            original_unit_id=kg.id, standard_quantity=Decimal("1"),
            standard_unit_id=kg.id, is_active=True,
        )
        db_session.add(rec)
        db_session.flush()
        ids.append(rec.id)
    db_session.commit()
    return product.id, ids


@pytest.fixture(autouse=True)
def _setup():
    register_all()


class _FakeProposal:
    """执行器直调用的最小 proposal 载体。"""

    def __init__(self, action, entity_id, payload):
        self.action = action
        self.entity_id = entity_id
        self.payload = payload
        self.revert_payload = {}
        self.snapshot = {}
        self.proposer_id = 1


def test_admin_rename_syncs_record_names(db_session, as_admin):
    """管理员改名后，价格记录快照列立即跟随（详情与列表都读同一列）。"""
    product_id, record_ids = _seed(db_session, ["旧商品名", "旧商品名"])

    resp = client.put(f"/api/v1/products/entity/{product_id}", json={"name": "新商品名"})
    assert resp.status_code == 200, resp.text

    detail = client.get(f"/api/v1/products/{record_ids[0]}")
    assert detail.status_code == 200, detail.text
    assert detail.json()["product_name"] == "新商品名"

    listed = client.get("/api/v1/products", params={"product_id": product_id})
    assert listed.status_code == 200, listed.text
    assert {r["product_name"] for r in listed.json()["items"]} == {"新商品名"}


def test_executor_revert_restores_each_old_name(db_session):
    """改名回滚按行还原旧名（含历史脏数据里各不相同的名字）。"""
    product_id, record_ids = _seed(db_session, ["旧商品名", "更早的名字"])
    executor = ProductExecutor()
    proposal = _FakeProposal("update", product_id, {"name": "新商品名"})

    result = executor.apply(db_session, proposal)
    db_session.commit()
    names_after = {
        r.id: r.product_name
        for r in db_session.query(ProductRecord).filter(ProductRecord.id.in_(record_ids)).all()
    }
    assert set(names_after.values()) == {"新商品名"}

    proposal.revert_payload = result.revert_payload
    executor.revert(db_session, proposal)
    db_session.commit()
    names_restored = {
        r.id: r.product_name
        for r in db_session.query(ProductRecord).filter(ProductRecord.id.in_(record_ids)).all()
    }
    assert names_restored[record_ids[0]] == "旧商品名"
    assert names_restored[record_ids[1]] == "更早的名字"


def test_rename_with_no_name_change_keeps_revert_payload_empty(db_session):
    """payload 不含 name（如只改品牌）时不做任何记录同步。"""
    product_id, record_ids = _seed(db_session, ["旧商品名"])
    executor = ProductExecutor()
    proposal = _FakeProposal("update", product_id, {"brand": "某品牌"})

    result = executor.apply(db_session, proposal)
    db_session.commit()
    assert "record_name_restore" not in result.revert_payload
    rec = db_session.query(ProductRecord).get(record_ids[0])
    assert rec.product_name == "旧商品名"
