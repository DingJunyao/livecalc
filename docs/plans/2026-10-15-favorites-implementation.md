# 收藏（原料 / 商品 / 菜谱）实现计划 —— 阶段 1（master 侧）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给原料 / 商品 / 菜谱加上收藏（心形 + 只看收藏筛选 + 列表置顶收藏 + 「我的收藏」聚合页），后端 + web + 本地离线模式全部可用，云端导出导入包含收藏（含补上商家收藏）。

**Architecture:** 新表 `user_favorites`（多态纯链接表，`(user_id, entity_type, entity_id)` 唯一）；新路由 `api/favorites.py`（登录直写、不走审批，对齐商家收藏）；三个既有列表端点新增 `favorites_first` / `favorites_only` 参数（默认 false，只有主列表页传 true）；web 抽 `useFavorites` composable + `FavoriteButton` 组件（含把商家收藏三处内联实现替换为该套件）；本地模式新增 IndexedDB store + handlers；导出导入按「实体先导、收藏按名字回填」两遍法（参照 `importer/importers/export.py:308` 既有先例）。

**Tech Stack:** FastAPI + SQLAlchemy + Alembic（SQLite/MySQL/PG 三引擎 SQL 脚本）；Vue 3 + Vuetify + Pinia + IndexedDB（本地模式）；pytest（后端测试）。

**Spec:** `docs/plans/2026-10-15-favorites-ai-meals-planner-design.md`（§3 阶段 1；§2 决策清单 #9/#10/#16）

**范围说明:** 本计划只覆盖 master 侧（后端 + web + 本地离线模式）。移动端（feat/mobile-app）在 master 合并完成后另出计划。

## Global Constraints

- **分支**：全部工作在 `master` 分支完成并提交；完成后按 AGENTS.md 流程合并到 `feat/mobile-app`（合并冲突主要可能在 `AGENTS.md` 记录区，两边保留）。
- **后端命令**：`cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/... -v`（虚拟环境在仓库根 `.venv`）。不新增后端依赖。
- **不启动服务**（前端/后端已有自动重载服务在跑）；**不手工改数据库**（迁移随后端重启生效）。
- **迁移产物**：每个建表改动同时给 alembic 迁移 + `backend/scripts/sql/<日期>_<topic>_{sqlite,mysql,postgresql}.sql`（与 PostGIS 无关，不提供 PostGIS 版）。
- **前端构建必须通过**：`cd frontend && npm run build`、`npm run check:i18n`、`npm run check:i18n:sources`、`npm run test:utils`；`npx tsc --noEmit` 以既有约 137 条噪音为基线（不新增）。web 无组件测试设施，Vue 组件以构建 + 实机验证为准。
- **i18n**：任何新文案必须三语同步（`zh-CN.json` / `en-US.json` / `ar.json`），`check:i18n` 校验键树一致；本地模式 handler 内不得出现中文字面量（`check:i18n:sources` 会报错），错误走 `localError('key')`。
- **测试基线**：后端既有 pytest 失败集合不得新增；`test:utils` 当前 52/52 全绿。
- **提交**：每个任务结束提交一次，Conventional Commits（`feat:` / `test:` 等）。
- **多态外键**：`user_favorites.entity_id` 不加跨表外键（多态 + 软删 + 导入重排行 id，项目既有约定）；实体存在性在 API 层校验。

## Review Focus

最可能让使用者出问题的五类输入 / 条件（每类都在对应任务的测试里钉住）：

1. **已软删实体**：收藏过的实体被软删后，聚合页与列表都不得再显示它（收藏行保留，实体复活后恢复可见）；对已软删实体加收藏必须 404。
2. **重复收藏**：双击 / 并发重复 POST 不得产生第二行（幂等 + 唯一约束兜底，IntegrityError 视为成功）。
3. **筛选叠加**：`favorites_only` 与既有特殊条件（如 `no_recent_price`）叠加时，`total` 必须与过滤后条数一致（分页不出现空页 / 漏项）。
4. **排序稳定性**：`favorites_first` 下非收藏项的相对顺序必须与不传参时一致；收藏组内保持原排序（否则翻页重复/漏项）。
5. **导入重映射**：导出文件里实体在目标库找不到（名字也兜底不到）时，收藏行必须跳过并计数，不得中断导入。

---

## 文件结构总览

**新建（后端）**
- `backend/app/models/user_favorite.py` —— `UserFavorite` 模型
- `backend/app/api/favorites.py` —— 收藏路由（聚合 / 单类 / 加 / 删）
- `backend/alembic/versions/20261015_0001_add_user_favorites.py`
- `backend/scripts/sql/20261015_user_favorites_sqlite.sql` / `_mysql.sql` / `_postgresql.sql`
- `backend/tests/test_user_favorites_api.py` —— 模型 + API + 列表参数测试
- `backend/tests/services/test_favorites_lifecycle.py` —— 合并 + 导出导入测试

**修改（后端）**
- `backend/app/models/__init__.py` —— 注册 `UserFavorite`
- `backend/app/main.py:791` 附近 —— 挂载 favorites 路由
- `backend/app/api/products_entity.py:137-286` —— `list_products` 加两个参数
- `backend/app/api/ingredient_extended.py:724-875` —— `get_ingredients` 加两个参数
- `backend/app/api/recipes.py:357-446` —— `get_recipes` 加两个参数
- `backend/app/services/proposals/executors/product_merge.py` —— 收藏搬迁/回滚
- `backend/app/services/proposals/executors/ingredient.py:120-206` —— 收藏删除/回滚
- `backend/app/services/ingredient_merger.py:85-125` —— 合并时删除源收藏
- `backend/app/services/export/reachability.py` —— `ExportSet` 加收藏 id 集合
- `backend/app/services/export/packaging.py` —— 导出收藏两份 JSON（含 `user_merchant_favorites.json`）
- `backend/app/services/export/serializers.py` —— 两个序列化函数
- `backend/app/services/importer/importers/export.py` —— 新增 `_import_user_favorites` 并接入执行顺序

**新建（web）**
- `frontend/src/composables/useFavorites.ts`
- `frontend/src/components/common/FavoriteButton.vue`
- `frontend/src/views/favorites/FavoritesView.vue`
- `frontend/src/api/local/handlers/favorites.ts`

**修改（web）**
- `frontend/src/views/data/MerchantsView.vue` —— 三处内联心形换成 `FavoriteButton` + `useFavorites`
- `frontend/src/views/data/ProductsView.vue` / `frontend/src/views/data/IngredientsView.vue` / `frontend/src/views/recipes/RecipesView.vue` —— 筛选项 + 请求参数 + 行内心形
- `frontend/src/views/products/ProductDetail.vue` / `frontend/src/views/ingredients/IngredientDetail.vue` / `frontend/src/views/recipes/RecipeDetail.vue` —— app-bar 心形
- `frontend/src/router/index.ts` —— `/favorites` 路由
- `frontend/src/components/layout/AppLayout.vue` —— 侧栏导航项
- `frontend/src/api/local/database.ts` —— `user_favorites` store（DB_VERSION 3→4）
- `frontend/src/api/local/proxy.ts` —— 收藏路由
- `frontend/src/api/local/handlers/products.ts` / `ingredients.ts` / `recipes.ts` —— 列表参数
- `frontend/src/api/local/handlers/exportImport.ts` —— 导出白名单 + 文件映射
- `frontend/src/locales/{zh-CN,en-US,ar}.json` —— `favorites.*` / `nav.favorites` / `routes.favorites` 键

---

### Task 1: 后端数据层 —— UserFavorite 模型 + 迁移 + 三引擎 SQL

**Files:**
- Create: `backend/app/models/user_favorite.py`
- Modify: `backend/app/models/__init__.py`
- Create: `backend/alembic/versions/20261015_0001_add_user_favorites.py`
- Create: `backend/scripts/sql/20261015_user_favorites_sqlite.sql`、`20261015_user_favorites_mysql.sql`、`20261015_user_favorites_postgresql.sql`
- Test: `backend/tests/test_user_favorites_api.py`

**Interfaces:**
- Produces: `app.models.user_favorite.UserFavorite`（列：`id / user_id / entity_type / entity_id / created_at`；唯一约束 `uq_user_favorites`）——后续所有任务依赖此模型。

- [ ] **Step 1: 写失败测试（唯一约束）**

创建 `backend/tests/test_user_favorites_api.py`：

```python
"""收藏（原料/商品/菜谱）的模型与 API 回归测试。

口径：收藏是个人私有数据（登录直写、不走审批）；纯链接表
（(user_id, entity_type, entity_id) 唯一，取消收藏=物理删）；列表端点
favorites_first / favorites_only 参数化且默认关闭。
"""
import pytest
from sqlalchemy.exc import IntegrityError

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def test_user_favorite_unique_constraint():
    Base.metadata.create_all(bind=engine)
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        db.commit()
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()
    finally:
        db.query(UserFavorite).filter(UserFavorite.entity_id == 999001).delete()
        db.commit()
        db.close()
```

- [ ] **Step 2: 运行确认失败**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -v`
Expected: FAIL —— `ModuleNotFoundError: No module named 'app.models.user_favorite'`

- [ ] **Step 3: 建模型**

创建 `backend/app/models/user_favorite.py`：

```python
"""用户收藏（原料 / 商品 / 菜谱）。

商家收藏沿用独立表 user_merchant_favorites（见该模型）；本表覆盖其余三类实体，
按 entity_type 多态解释 entity_id。纯链接表：取消收藏 = 物理删除
（对齐 user_merchant_favorites 的模式）。
entity_id 不加跨表外键（多态 + 软删 + 导出导入重排行 id），存在性由 API 层校验。
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from app.core.database import Base


class UserFavorite(Base):
    __tablename__ = "user_favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "entity_type", "entity_id", name="uq_user_favorites"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    entity_type = Column(String(20), nullable=False)  # 'ingredient' | 'product' | 'recipe'
    entity_id = Column(Integer, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 4: 注册模型**

修改 `backend/app/models/__init__.py`：在 `from app.models.user_ingredient_preference import UserIngredientPreference` 一行之后追加

```python
from app.models.user_favorite import UserFavorite
```

并在 `__all__` 列表中 `"UserIngredientPreference",` 之后追加 `"UserFavorite",`。

- [ ] **Step 5: 建 alembic 迁移**

创建 `backend/alembic/versions/20261015_0001_add_user_favorites.py`：

```python
"""add user_favorites table

三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。
纯链接表：取消收藏=物理删除。entity_id 多态，不加跨表外键（软删 + 导入重排 id），
存在性由 API 层校验。

配套 SQL 脚本（按引擎）：
    backend/scripts/sql/20261015_user_favorites_{sqlite,mysql,postgresql}.sql

Revision ID: 20261015_0001
Revises: 20261013_0001
Create Date: 2026-10-15
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20261015_0001'
down_revision: Union[str, None] = '20261013_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = 'user_favorites'


def _has_table(table_name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return table_name in insp.get_table_names()


def upgrade() -> None:
    if _has_table(TABLE):
        return
    op.create_table(
        TABLE,
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('entity_type', sa.String(20), nullable=False),
        sa.Column('entity_id', sa.Integer(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('CURRENT_TIMESTAMP'),
        ),
        sa.UniqueConstraint('user_id', 'entity_type', 'entity_id', name='uq_user_favorites'),
    )
    op.create_index('ix_user_favorites_user_id', TABLE, ['user_id'])
    op.create_index('ix_user_favorites_entity_id', TABLE, ['entity_id'])


def downgrade() -> None:
    if _has_table(TABLE):
        op.drop_table(TABLE)
```

- [ ] **Step 6: 写三引擎 SQL 脚本**

`backend/scripts/sql/20261015_user_favorites_sqlite.sql`：

```sql
-- 20261015 user_favorites（SQLite）
-- 三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。
-- 纯链接表：取消收藏=物理删除。entity_id 多态，不加跨表外键（软删 + 导入重排 id）。

CREATE TABLE IF NOT EXISTS user_favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorites UNIQUE (user_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS ix_user_favorites_user_id ON user_favorites (user_id);
CREATE INDEX IF NOT EXISTS ix_user_favorites_entity_id ON user_favorites (entity_id);

-- 回滚：
-- DROP TABLE IF EXISTS user_favorites;
```

`backend/scripts/sql/20261015_user_favorites_mysql.sql`：

```sql
-- 20261015 user_favorites（MySQL）
-- 三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。

CREATE TABLE IF NOT EXISTS user_favorites (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorites UNIQUE (user_id, entity_type, entity_id),
    INDEX ix_user_favorites_user_id (user_id),
    INDEX ix_user_favorites_entity_id (entity_id),
    CONSTRAINT fk_user_favorites_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 回滚：
-- DROP TABLE IF EXISTS user_favorites;
```

`backend/scripts/sql/20261015_user_favorites_postgresql.sql`：

```sql
-- 20261015 user_favorites（PostgreSQL，与 PostGIS 无关）
-- 三类实体的收藏（原料/商品/菜谱）；商家收藏沿用 user_merchant_favorites。

CREATE TABLE IF NOT EXISTS user_favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_favorites UNIQUE (user_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS ix_user_favorites_user_id ON user_favorites (user_id);
CREATE INDEX IF NOT EXISTS ix_user_favorites_entity_id ON user_favorites (entity_id);

-- 回滚：
-- DROP TABLE IF EXISTS user_favorites;
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -v`
Expected: PASS（1 passed）

- [ ] **Step 8: 提交**

```bash
git add backend/app/models/user_favorite.py backend/app/models/__init__.py \
  backend/alembic/versions/20261015_0001_add_user_favorites.py \
  backend/scripts/sql/20261015_user_favorites_sqlite.sql \
  backend/scripts/sql/20261015_user_favorites_mysql.sql \
  backend/scripts/sql/20261015_user_favorites_postgresql.sql \
  backend/tests/test_user_favorites_api.py
git commit -m "feat(favorites): user_favorites 表（原料/商品/菜谱）+ 迁移与三引擎 SQL"
```

---

### Task 2: 后端收藏 API（favorites 路由）

**Files:**
- Create: `backend/app/api/favorites.py`
- Modify: `backend/app/main.py`（在 `merchants.router` 挂载行之后插入）
- Test: `backend/tests/test_user_favorites_api.py`（追加）

**Interfaces:**
- Consumes: `UserFavorite`（Task 1）
- Produces:
  - `GET /api/v1/favorites` → `{"ingredients": [FavoriteItem], "products": [FavoriteItem], "recipes": [FavoriteItem], "merchants": [MerchantResponse]}`
  - `GET /api/v1/favorites/{entity_type}` → `[FavoriteItem]`（`entity_type ∈ {ingredient, product, recipe}`）
  - `POST | DELETE /api/v1/favorites/{entity_type}/{entity_id}` → `{"ok": true}`
  - `FavoriteItem` = `{"id": int, "name": str, "subtitle": str | None, "image": str | None}`
  - 后续 web 任务按这些形状消费。

- [ ] **Step 1: 写失败测试（API 行为）**

在 `backend/tests/test_user_favorites_api.py` 追加：

```python
def _seed_favorite_entities(db):
    """建 1 原料 / 1 商品 / 1 菜谱（名字带唯一后缀），返回 id 与清理信息。"""
    import uuid

    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.recipe import Recipe

    suffix = uuid.uuid4().hex[:10]
    ing = Ingredient(name=f"收藏测试原料_{suffix}", is_active=True)
    db.add(ing)
    db.commit()
    prod = Product(name=f"收藏测试商品_{suffix}", ingredient_id=ing.id, is_active=True)
    rec = Recipe(name=f"收藏测试菜谱_{suffix}", category="主食", user_id=FakeUser.id, is_active=True)
    db.add_all([prod, rec])
    db.commit()
    return {"ingredient": ing.id, "product": prod.id, "recipe": rec.id}


def _cleanup_favorite_entities(ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.recipe import Recipe
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.query(UserFavorite).filter(
            UserFavorite.entity_id.in_(list(ids.values()))
        ).delete(synchronize_session=False)
        db.query(Product).filter(Product.id == ids["product"]).delete(synchronize_session=False)
        db.query(Recipe).filter(Recipe.id == ids["recipe"]).delete(synchronize_session=False)
        db.query(Ingredient).filter(Ingredient.id == ids["ingredient"]).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def test_favorite_round_trip_all_types(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        for entity_type, entity_id in ids.items():
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
            # 幂等：重复收藏仍 ok 且只有一行
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200, resp.text

        resp = client.get("/api/v1/favorites")
        assert resp.status_code == 200, resp.text
        payload = resp.json()
        for entity_type, entity_id in ids.items():
            listed = [it["id"] for it in payload[f"{entity_type}s"]]
            assert entity_id in listed, (entity_type, payload)
        assert isinstance(payload["merchants"], list)

        resp = client.get("/api/v1/favorites/recipe")
        assert resp.status_code == 200, resp.text
        assert ids["recipe"] in [it["id"] for it in resp.json()]

        for entity_type, entity_id in ids.items():
            resp = client.delete(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
        resp = client.get("/api/v1/favorites")
        for entity_type, entity_id in ids.items():
            assert entity_id not in [it["id"] for it in resp.json()[f"{entity_type}s"]]
    finally:
        _cleanup_favorite_entities(ids)


def test_favorite_unknown_entity_404(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    client = TestClient(app)
    resp = client.post("/api/v1/favorites/recipe/999000123")
    assert resp.status_code == 404, resp.text
    resp = client.post("/api/v1/favorites/not_a_type/1")
    assert resp.status_code == 400, resp.text


def test_favorite_soft_deleted_entity_404_and_hidden(as_admin):
    """软删实体：加收藏 404；收藏过的实体被软删后不再出现在列表。"""
    from starlette.testclient import TestClient
    from app.main import app
    from app.models.recipe import Recipe

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        assert client.post(f"/api/v1/favorites/recipe/{ids['recipe']}").status_code == 200
        # 软删该菜谱
        db = TestingSessionLocal()
        try:
            db.query(Recipe).filter(Recipe.id == ids["recipe"]).update({"is_active": False})
            db.commit()
        finally:
            db.close()
        # 已软删 → 再加收藏 404
        resp = client.post(f"/api/v1/favorites/recipe/{ids['recipe']}")
        assert resp.status_code == 404, resp.text
        # 列表不显示
        resp = client.get("/api/v1/favorites/recipe")
        assert ids["recipe"] not in [it["id"] for it in resp.json()]
    finally:
        db = TestingSessionLocal()
        try:
            db.query(Recipe).filter(Recipe.id == ids["recipe"]).update({"is_active": True})
            db.commit()
        finally:
            db.close()
        _cleanup_favorite_entities(ids)
```

- [ ] **Step 2: 运行确认失败**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -v`
Expected: FAIL —— 404/405（路由不存在）

- [ ] **Step 3: 实现路由**

创建 `backend/app/api/favorites.py`：

```python
"""收藏：原料 / 商品 / 菜谱（商家收藏见 api/merchants.py）。

收藏是个人私有数据：登录即可读写，不走 proposals 审批（对齐商家收藏）。
"""
from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.security import get_current_user
from app.models.user import User
from app.models.user_favorite import UserFavorite

router = APIRouter()

_ENTITY_TYPES = ("ingredient", "product", "recipe")


def _favorite_items(db: Session, user_id: int, entity_type: str) -> list:
    """按收藏时间倒序返回某类型的收藏条目（轻量浏览信息）。

    不复用各列表页的 display override 与待审逻辑：聚合页只要可点击的浏览项，
    把审批态混进收藏列表反而容易误导。
    """
    fav_rows = (
        db.query(UserFavorite)
        .filter(UserFavorite.user_id == user_id, UserFavorite.entity_type == entity_type)
        .order_by(UserFavorite.created_at.desc(), UserFavorite.id.desc())
        .all()
    )
    ids = [f.entity_id for f in fav_rows]
    if not ids:
        return []
    items = []
    if entity_type == "ingredient":
        from app.models.nutrition import Ingredient

        rows = db.query(Ingredient).filter(
            Ingredient.id.in_(ids), Ingredient.is_active == True
        ).all()
        items = [
            {"id": r.id, "name": r.name, "subtitle": None, "image": None} for r in rows
        ]
    elif entity_type == "product":
        from app.models.product_entity import Product

        rows = db.query(Product).options(joinedload(Product.ingredient)).filter(
            Product.id.in_(ids), Product.is_active == True
        ).all()
        items = [
            {
                "id": r.id,
                "name": r.name,
                "subtitle": r.ingredient.name if r.ingredient else None,
                "image": r.image_url,
            }
            for r in rows
        ]
    elif entity_type == "recipe":
        from app.models.recipe import Recipe

        rows = db.query(Recipe).filter(
            Recipe.id.in_(ids), Recipe.is_active == True
        ).all()
        items = [
            {
                "id": r.id,
                "name": r.name,
                "subtitle": r.category,
                "image": (r.images or [None])[0],
            }
            for r in rows
        ]
    order = {row_id: idx for idx, row_id in enumerate(ids)}
    items.sort(key=lambda it: order.get(it["id"], 1 << 30))
    return items


def _ensure_favoritable(db: Session, entity_type: str, entity_id: int) -> None:
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    if entity_type == "ingredient":
        from app.models.nutrition import Ingredient

        row = db.query(Ingredient.id).filter(
            Ingredient.id == entity_id, Ingredient.is_active == True
        ).first()
    elif entity_type == "product":
        from app.models.product_entity import Product

        row = db.query(Product.id).filter(
            Product.id == entity_id, Product.is_active == True
        ).first()
    else:
        from app.models.recipe import Recipe

        row = db.query(Recipe.id).filter(
            Recipe.id == entity_id, Recipe.is_active == True
        ).first()
    if row is None:
        raise LocalizedHTTPException(status_code=404, message='收藏对象不存在或已删除')


@router.get("")
@router.get("/")
async def list_all_favorites(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """聚合四类收藏（供「我的收藏」页）。商家读既有收藏表并补齐有效币种。"""
    from app.api.merchants import _attach_effective_currency
    from app.models.merchant import Merchant
    from app.models.user_merchant_favorite import UserMerchantFavorite

    merchant_ids = [
        r[0]
        for r in db.query(UserMerchantFavorite.merchant_id)
        .filter(UserMerchantFavorite.user_id == current_user.id)
        .all()
    ]
    merchants = []
    if merchant_ids:
        merchants = db.query(Merchant).filter(Merchant.id.in_(merchant_ids)).all()
        _attach_effective_currency(db, merchants)
    return {
        "ingredients": _favorite_items(db, current_user.id, "ingredient"),
        "products": _favorite_items(db, current_user.id, "product"),
        "recipes": _favorite_items(db, current_user.id, "recipe"),
        "merchants": merchants,
    }


@router.get("/{entity_type}")
async def list_favorites_by_type(
    entity_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    return _favorite_items(db, current_user.id, entity_type)


@router.post("/{entity_type}/{entity_id}")
async def add_favorite(
    entity_type: str,
    entity_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """收藏（幂等）。"""
    _ensure_favoritable(db, entity_type, entity_id)
    existing = db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == entity_type,
        UserFavorite.entity_id == entity_id,
    ).first()
    if existing:
        return {"ok": True}
    db.add(UserFavorite(
        user_id=current_user.id, entity_type=entity_type, entity_id=entity_id
    ))
    try:
        db.commit()
    except IntegrityError:
        # 并发双击：唯一约束兜底，视为已收藏
        db.rollback()
    return {"ok": True}


@router.delete("/{entity_type}/{entity_id}")
async def remove_favorite(
    entity_type: str,
    entity_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """取消收藏（幂等，物理删）。"""
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == entity_type,
        UserFavorite.entity_id == entity_id,
    ).delete()
    db.commit()
    return {"ok": True}
```

- [ ] **Step 4: 挂载路由**

修改 `backend/app/main.py`：在

```python
app.include_router(merchants.router, prefix="/api/v1/merchants", dependencies=[Depends(get_session_currency_override)], tags=["商家"])
```

之后插入（并在文件顶部与其它 `from app.api import ...` 同处追加 `favorites` 导入）：

```python
app.include_router(favorites.router, prefix="/api/v1/favorites", dependencies=[Depends(get_session_currency_override)], tags=["收藏"])
```

- [ ] **Step 5: 运行测试确认通过**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -v`
Expected: PASS（5 passed）

- [ ] **Step 6: 提交**

```bash
git add backend/app/api/favorites.py backend/app/main.py backend/tests/test_user_favorites_api.py
git commit -m "feat(favorites): 收藏 API（聚合/单类/加/删，登录直写不走审批）"
```

---

### Task 3: 列表端点收藏参数（favorites_first / favorites_only）

**Files:**
- Modify: `backend/app/api/products_entity.py:137-286`
- Modify: `backend/app/api/ingredient_extended.py:724-875`
- Modify: `backend/app/api/recipes.py:357-446`
- Test: `backend/tests/test_user_favorites_api.py`（追加）

**Interfaces:**
- Consumes: `UserFavorite`（Task 1）
- Produces: 三个列表端点的 `favorites_first: bool = False`、`favorites_only: bool = False` 查询参数（web 任务按此传参）。

- [ ] **Step 1: 写失败测试**

在 `backend/tests/test_user_favorites_api.py` 追加：

```python
def _list_ids(client, path, params=None):
    resp = client.get(path, params=params or {"limit": 1000})
    assert resp.status_code == 200, resp.text
    return [it["id"] for it in resp.json()["items"]]


def test_favorites_only_and_first_products(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        base = _list_ids(client, "/api/v1/products/entity")
        assert ids["product"] in base

        assert client.post(f"/api/v1/favorites/product/{ids['product']}").status_code == 200

        # favorites_only：只有该商品，且 total 与条数一致（分页一致性）
        resp = client.get("/api/v1/products/entity", params={"favorites_only": "true", "limit": 1000})
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["product"]]
        assert payload["total"] == 1

        # favorites_first：收藏项在最前，非收藏项相对顺序与 base 一致（去掉收藏项后的序列）
        pinned = _list_ids(client, "/api/v1/products/entity", {"favorites_first": "true"})
        assert pinned[0] == ids["product"]
        assert [i for i in pinned if i != ids["product"]] == [i for i in base if i != ids["product"]]

        # 默认（不传参）：顺序与 base 完全一致（行为不变）
        assert _list_ids(client, "/api/v1/products/entity") == base

        # favorites_only 与既有特殊条件叠加：total 仍与条数一致
        resp = client.get(
            "/api/v1/products/entity",
            params={"favorites_only": "true", "no_recent_price": "true", "limit": 1000},
        )
        payload = resp.json()
        assert payload["total"] == len(payload["items"])

        client.delete(f"/api/v1/favorites/product/{ids['product']}")
    finally:
        _cleanup_favorite_entities(ids)


def test_favorites_only_and_first_ingredients_and_recipes(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        client.post(f"/api/v1/favorites/ingredient/{ids['ingredient']}")
        resp = client.get("/api/v1/ingredients", params={"favorites_only": "true", "limit": 1000})
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["ingredient"]]
        assert payload["total"] == 1
        pinned = _list_ids(client, "/api/v1/ingredients", {"favorites_first": "true", "sort_by": "name"})
        assert pinned[0] == ids["ingredient"]

        client.post(f"/api/v1/favorites/recipe/{ids['recipe']}")
        resp = client.get("/api/v1/recipes", params={"favorites_only": "true", "limit": 1000})
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["recipe"]]
        assert payload["total"] == 1
        pinned = _list_ids(client, "/api/v1/recipes", {"favorites_first": "true"})
        assert pinned[0] == ids["recipe"]

        client.delete(f"/api/v1/favorites/ingredient/{ids['ingredient']}")
        client.delete(f"/api/v1/favorites/recipe/{ids['recipe']}")
    finally:
        _cleanup_favorite_entities(ids)
```

- [ ] **Step 2: 运行确认失败**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -k favorites_only -v`
Expected: FAIL（参数被忽略：favorites_only 返回全量 / total 不等）

- [ ] **Step 3: 改 products_entity.py**

在 `list_products` 的签名中（`no_recent_price` 一行之后）追加：

```python
    favorites_only: bool = Query(False, description="仅返回当前用户收藏的商品"),
    favorites_first: bool = Query(False, description="收藏的商品排在最前（默认关闭）"),
```

在函数体 `recent_cutoff = ...` 之后追加：

```python
    fav_subq = None
    fav_case = None
    if favorites_only or favorites_first:
        from app.models.user_favorite import UserFavorite

        fav_subq = db.query(UserFavorite.entity_id).filter(
            UserFavorite.user_id == current_user.id,
            UserFavorite.entity_type == "product",
        ).subquery()
        if favorites_first:
            from sqlalchemy import case

            fav_case = case((Product.id.in_(fav_subq), 0), else_=1)
```

然后对 **两个分支**（`sort_by == "price_records"` 分支与 else 分支）都做两处修改：

1. 在 `_apply_product_special_conditions(...)` 之后追加：

```python
        if favorites_only:
            query = query.filter(Product.id.in_(fav_subq))
```

2. 把该分支的 `order_by(...)` 前缀改为 `fav_case`（若非 None）：

```python
        order_prefix = [fav_case] if fav_case is not None else []
        products = query.order_by(*order_prefix, desc(subquery.c.record_count), desc(Product.created_at)).offset(skip).limit(limit).all()
```

（else 分支同理：`query.order_by(*order_prefix, desc(Product.created_at))` / `desc(Product.updated_at)`。）

- [ ] **Step 4: 改 ingredient_extended.py**

在 `get_ingredients` 签名中（`no_recent_price` 之后）追加同样的两个参数（描述里写「原料」）。在 `recent_cutoff = ...` 之后追加：

```python
        fav_subq = None
        fav_case = None
        if favorites_only or favorites_first:
            from app.models.user_favorite import UserFavorite

            fav_subq = db.query(UserFavorite.entity_id).filter(
                UserFavorite.user_id == current_user.id,
                UserFavorite.entity_type == "ingredient",
            ).subquery()
            if favorites_first:
                from sqlalchemy import case

                fav_case = case((Ingredient.id.in_(fav_subq), 0), else_=1)
```

对 **两个分支 + price_records 分支的 `total_query`** 做同样修改：

1. 每个 `_apply_ingredient_special_conditions(...)` 调用之后追加 `if favorites_only: query = query.filter(Ingredient.id.in_(fav_subq))`（`total_query` 上同样追加一次）。
2. price_records 分支排序：

```python
        order_prefix = [fav_case] if fav_case is not None else []
        ingredients = query.order_by(
            *order_prefix,
            subquery.c.record_count.desc(),
            Ingredient.id,
        ).offset(skip).limit(limit).all()
```

3. else 分支排序（`sort_by == "name"` / `created_at` 两个 `order_by` 前都加前缀）：

```python
        order_prefix = [fav_case] if fav_case is not None else []
        if sort_by == "name":
            query = query.order_by(*order_prefix, Ingredient.name)
        elif sort_by == "created_at":
            query = query.order_by(*order_prefix, Ingredient.created_at.desc())
```

注意：`sort_by == "name"` 且传了 `favorites_first` 时也要有稳定的次级键；`Ingredient.name` 已能保证（同名概率低，可接受）。

- [ ] **Step 5: 改 recipes.py**

在 `get_recipes` 签名中（`include_cost` 之后）追加：

```python
    favorites_only: bool = Query(False, description="仅返回当前用户收藏的菜谱"),
    favorites_first: bool = Query(False, description="收藏的菜谱排在最前（默认关闭）"),
```

在 `exclude_blacklist_ingredients` 处理之后（即 `all_recipes_query` 已成形处）追加：

```python
        fav_subq = None
        fav_case = None
        if favorites_only or favorites_first:
            from app.models.user_favorite import UserFavorite
            from sqlalchemy import case

            fav_subq = db.query(UserFavorite.entity_id).filter(
                UserFavorite.user_id == current_user.id,
                UserFavorite.entity_type == "recipe",
            ).subquery()
            if favorites_first:
                fav_case = case((Recipe.id.in_(fav_subq), 0), else_=1)
```

在 `_apply_recipe_special_conditions(...)` 之后追加：

```python
        if favorites_only:
            all_recipes_query = all_recipes_query.filter(Recipe.id.in_(fav_subq))
```

并把排序改为：

```python
        order_prefix = [fav_case] if fav_case is not None else []
        total = all_recipes_query.count()
        recipes = all_recipes_query.order_by(*order_prefix, Recipe.created_at.desc()).offset(skip).limit(limit).all()
```

- [ ] **Step 6: 运行测试确认通过**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py -v`
Expected: PASS（7 passed）

- [ ] **Step 7: 回归既有列表端点测试**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_recent_price_filter.py tests/test_entity_unit_nesting_api.py tests/test_ingredient_latest_price_weighted.py -v`
Expected: 全 PASS（确认参数化未破坏既有筛选/排序）

- [ ] **Step 8: 提交**

```bash
git add backend/app/api/products_entity.py backend/app/api/ingredient_extended.py backend/app/api/recipes.py backend/tests/test_user_favorites_api.py
git commit -m "feat(favorites): 商品/原料/菜谱列表新增 favorites_first / favorites_only 参数"
```

---

### Task 4: 合并联动（商品 / 原料）+ 收藏搬迁与回滚

**Files:**
- Modify: `backend/app/services/proposals/executors/product_merge.py`
- Modify: `backend/app/services/proposals/executors/ingredient.py`（`_apply_merge` / `_revert_merge`）
- Modify: `backend/app/services/ingredient_merger.py`（`merge_ingredients`）
- Test: `backend/tests/services/test_favorites_lifecycle.py`

**Interfaces:**
- Consumes: `UserFavorite`（Task 1）
- Produces: 商品合并 / 原料合并后源实体收藏被删除；revert 按快照恢复。

口径（对齐 `merchant_merge.py` 的既有决策）：合并时**删除**源收藏（不搬迁——同一用户可能同时收藏源与目标，搬迁会撞唯一约束）；回滚时按快照重新插入。

- [ ] **Step 1: 写失败测试**

创建 `backend/tests/services/test_favorites_lifecycle.py`：

```python
"""收藏的生命周期联动：合并搬迁/回滚 + 导出导入往返。"""
import uuid

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


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
```

- [ ] **Step 2: 运行确认失败**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/services/test_favorites_lifecycle.py -v`
Expected: FAIL —— 源收藏仍在（`[src_id, tgt_id] != [tgt_id]`）

- [ ] **Step 3: 改 ingredient_merger.py（删除源收藏）**

在 `IngredientMerger.merge_ingredients` 的步骤列表中，在「3. 更新营养数据映射」之前插入：

```python
            # 2.5 删除源食材的收藏（口径对齐商家合并：不搬迁，避免撞唯一约束；
            #     回滚由提案执行器的快照恢复）
            from app.models.user_favorite import UserFavorite

            self.db.query(UserFavorite).filter(
                UserFavorite.entity_type == "ingredient",
                UserFavorite.entity_id.in_(source_ingredient_ids),
            ).delete(synchronize_session=False)
```

- [ ] **Step 4: 改 executors/ingredient.py（快照 + 回滚）**

在 `_apply_merge` 的 `snapshot = {...}` 字典中追加（与 `"sources"` 同级）：

```python
            "favorites": [
                {"id": f.id, "user_id": f.user_id, "entity_id": f.entity_id}
                for f in db.query(UserFavorite)
                    .filter(UserFavorite.entity_type == "ingredient",
                            UserFavorite.entity_id.in_(source_ids)).all()
            ],
```

并在文件顶部 import 区追加 `from app.models.user_favorite import UserFavorite`。

在 `_revert_merge` 的「1. 还原 recipe_ingredients」之前插入：

```python
        # 0. 还原源食材收藏（合并时被删，按快照恢复；已存在则跳过）
        from app.models.user_favorite import UserFavorite

        for item in snap.get("favorites", []):
            existing = db.query(UserFavorite).filter(
                UserFavorite.user_id == item["user_id"],
                UserFavorite.entity_type == "ingredient",
                UserFavorite.entity_id == item["entity_id"],
            ).first()
            if existing is None:
                db.add(UserFavorite(
                    user_id=item["user_id"],
                    entity_type="ingredient",
                    entity_id=item["entity_id"],
                ))
```

- [ ] **Step 5: 改 product_merge.py（快照 / 删除 / 回滚）**

`build_snapshot`：在返回 dict 中追加 `"affected_favorites_count": fav_cnt,`，其中

```python
        from app.models.user_favorite import UserFavorite
        fav_cnt = 0
        if eid:
            fav_cnt = db.query(UserFavorite).filter(
                UserFavorite.entity_type == "product",
                UserFavorite.entity_id == eid,
            ).count()
```

`preview`：返回 dict 追加 `"affected_favorites": fav_cnt,`（同样方式统计）。

`apply`：在「软删源商品」之前插入

```python
        # 删除源商品收藏（口径对齐商家合并：不搬迁，回滚按快照恢复）
        from app.models.user_favorite import UserFavorite

        fav_rows = db.query(UserFavorite).filter(
            UserFavorite.entity_type == "product",
            UserFavorite.entity_id == eid,
        ).all()
        snapshot["favorites"] = [
            {"id": f.id, "user_id": f.user_id, "entity_id": f.entity_id} for f in fav_rows
        ]
        if fav_rows:
            db.query(UserFavorite).filter(
                UserFavorite.id.in_([f.id for f in fav_rows])
            ).delete(synchronize_session=False)
```

`revert`：追加

```python
        # 恢复源商品收藏
        from app.models.user_favorite import UserFavorite

        for item in snap.get("favorites", []):
            existing = db.query(UserFavorite).filter(
                UserFavorite.user_id == item["user_id"],
                UserFavorite.entity_type == "product",
                UserFavorite.entity_id == item["entity_id"],
            ).first()
            if existing is None:
                db.add(UserFavorite(
                    user_id=item["user_id"],
                    entity_type="product",
                    entity_id=item["entity_id"],
                ))
```

- [ ] **Step 6: 运行测试确认通过**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/services/test_favorites_lifecycle.py -v`
Expected: PASS

- [ ] **Step 7: 回归既有合并测试**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/ -k "merge or nested_unit" -v`
Expected: 与基线一致（不新增失败）

- [ ] **Step 8: 提交**

```bash
git add backend/app/services/ingredient_merger.py backend/app/services/proposals/executors/ingredient.py backend/app/services/proposals/executors/product_merge.py backend/tests/services/test_favorites_lifecycle.py
git commit -m "feat(favorites): 商品/原料合并删除源收藏并可回滚（对齐商家合并口径）"
```

---

### Task 5: 导出导入（含补上商家收藏）

**Files:**
- Modify: `backend/app/services/export/reachability.py`（`ExportSet` + 两个 collect 函数）
- Modify: `backend/app/services/export/serializers.py`（追加两个序列化函数）
- Modify: `backend/app/services/export/packaging.py`（payload + manifest + writestr）
- Modify: `backend/app/services/importer/importers/export.py`（`_import_user_favorites` + 执行顺序 + 顶部 import）
- Test: `backend/tests/services/test_favorites_lifecycle.py`（追加往返测试）

**Interfaces:**
- Consumes: `UserFavorite`、`UserMerchantFavorite`
- Produces: 导出 ZIP 新增 `user_favorites.json`（元素 `{id, entity_type, entity_id, entity_name}`）与 `user_merchant_favorites.json`（元素 `{id, merchant_id, merchant_name}`）；导入侧 `_import_user_favorites(collection)`（归属导入用户、按 mapping + 名字兜底解析、缺失跳过并计数到 `stats`）。

- [ ] **Step 1: 写失败测试（导出往返）**

在 `backend/tests/services/test_favorites_lifecycle.py` 追加：

```python
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
            finally:
                db.close()
    finally:
        _cleanup([src_id, tgt_id])
```

- [ ] **Step 2: 运行确认失败**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/services/test_favorites_lifecycle.py -k export -v`
Expected: FAIL —— ZIP 中没有 `user_favorites.json`

- [ ] **Step 3: 扩展 ExportSet 与收集器**

`backend/app/services/export/reachability.py`：

- `ExportSet` 追加字段：

```python
    favorite_ids: set = field(default_factory=set)
    merchant_favorite_ids: set = field(default_factory=set)
```

- `collect_full_set` 追加（与 `es.user_place_ids = ...` 同级）：

```python
    es.favorite_ids = {f.id for f in db.query(UserFavorite).all()}
    es.merchant_favorite_ids = {f.id for f in db.query(UserMerchantFavorite).all()}
```

- `collect_mine_set` 追加：

```python
    es.favorite_ids = {
        f.id for f in db.query(UserFavorite).filter(UserFavorite.user_id == user_id).all()
    }
    es.merchant_favorite_ids = {
        f.id for f in db.query(UserMerchantFavorite)
        .filter(UserMerchantFavorite.user_id == user_id).all()
    }
```

（两个函数顶部按需 `from app.models.user_favorite import UserFavorite`、`from app.models.user_merchant_favorite import UserMerchantFavorite`。）

- [ ] **Step 4: 序列化函数**

`backend/app/services/export/serializers.py` 末尾追加：

```python
def serialize_user_favorite(fav: Any, entity_name: Optional[str]) -> dict:
    """UserFavorite → user_favorites.json 元素。

    entity_name 由调用方按类型解析冗余注入：导入会重排实体 id，
    优先按名字兜底解析（见 importer）。
    """
    return {
        "id": fav.id,
        "entity_type": fav.entity_type,
        "entity_id": fav.entity_id,
        "entity_name": entity_name,
        "created_at": to_iso(fav.created_at),
    }


def serialize_merchant_favorite(fav: Any, merchant_name: Optional[str]) -> dict:
    """UserMerchantFavorite → user_merchant_favorites.json 元素。"""
    return {
        "id": fav.id,
        "merchant_id": fav.merchant_id,
        "merchant_name": merchant_name,
        "created_at": to_iso(fav.created_at),
    }
```

（若 `serializers.py` 未导入 `Optional`，以文件顶部既有导入风格补齐。）

- [ ] **Step 5: 打包（payload / manifest / writestr）**

`backend/app/services/export/packaging.py`：

在 `places_payload = _safe_build(...)` 之后追加：

```python
    favorite_rows = _query(UserFavorite, es.favorite_ids)
    merchant_favorite_rows = _query(UserMerchantFavorite, es.merchant_favorite_ids)

    def _build_favorites():
        ing_names = {}  # 复用本文件既有的名称解析工具（如 _ingredient_name_map）
        out = []
        for f in favorite_rows:
            name = None
            if f.entity_type == "ingredient":
                name = ing_names.get(f.entity_id)
            elif f.entity_type == "product":
                name = prod_id_to_name.get(f.entity_id)
            else:
                name = recipe_id_to_name.get(f.entity_id)
            out.append(S.serialize_user_favorite(f, name))
        return out
```

（`recipe_id_to_name` 若不存在，按本文件既有风格用一次批量查询构建：`{r.id: r.name for r in db.query(Recipe).filter(Recipe.id.in_(ri_ids)).all()}`；`prod_id_to_name` 已存在。）

```python
    merchant_favorite_payload = _safe_build(
        "user_merchant_favorites",
        lambda: [
            S.serialize_merchant_favorite(f, merchant_id_to_name.get(f.merchant_id))
            for f in merchant_favorite_rows
        ],
    )
    favorites_payload = _safe_build("user_favorites", _build_favorites)
```

manifest 修改：`"extended"` 列表追加 `"user_favorites", "user_merchant_favorites"`；`"counts"` 追加两行。zip 写入区追加（与 `user_places.json` 同级）：

```python
            zf.writestr("user_favorites.json", json.dumps(favorites_payload, ensure_ascii=False, indent=2))
            zf.writestr("user_merchant_favorites.json", json.dumps(merchant_favorite_payload, ensure_ascii=False, indent=2))
```

顶部 import 追加两个模型（`_query` 的用法与本文件既有行一致）。

- [ ] **Step 6: 导入两遍法**

`backend/app/services/importer/importers/export.py`：

在 `_import_user_places` 方法之后新增：

```python
    def _import_user_favorites(self, collection):
        """导入收藏（原料/商品/菜谱 + 商家）。

        实体会被重排行 id，故以 mapping 为主、导出附带的名字为兜底解析；
        解析不到的行跳过（计数到 stats）。归属导入用户；已存在则跳过（幂等）。
        """
        from app.models.user_favorite import UserFavorite
        from app.models.user_merchant_favorite import UserMerchantFavorite

        imported = 0
        data = self._load_json(collection, "user_favorites.json")
        for item in data or []:
            entity_type = item.get("entity_type", "")
            old_id = item.get("entity_id")
            new_id = None
            name = (item.get("entity_name") or "").strip()
            if entity_type == "ingredient":
                new_id = self.mapping.ingredients.get(old_id)
                if not new_id and name:
                    from app.models.nutrition import Ingredient
                    row = self.db.query(Ingredient).filter(
                        Ingredient.name == name, Ingredient.is_active.is_(True)
                    ).first()
                    new_id = row.id if row else None
            elif entity_type == "product":
                new_id = self.mapping.products.get(old_id)
                if not new_id and name:
                    from app.models.product_entity import Product
                    row = self.db.query(Product).filter(
                        Product.name == name, Product.is_active.is_(True)
                    ).first()
                    new_id = row.id if row else None
            elif entity_type == "recipe":
                new_id = self.mapping.recipes.get(old_id)
                if not new_id and name:
                    from app.models.recipe import Recipe
                    row = self.db.query(Recipe).filter(
                        Recipe.name == name, Recipe.is_active.is_(True)
                    ).first()
                    new_id = row.id if row else None
            else:
                continue
            if not new_id:
                continue
            exists = self.db.query(UserFavorite).filter(
                UserFavorite.user_id == self.user_id,
                UserFavorite.entity_type == entity_type,
                UserFavorite.entity_id == new_id,
            ).first()
            if exists:
                continue
            self.db.add(UserFavorite(
                user_id=self.user_id, entity_type=entity_type, entity_id=new_id,
            ))
            imported += 1
        self.result.stats["user_favorites"] = imported

        imported_m = 0
        data_m = self._load_json(collection, "user_merchant_favorites.json")
        for item in data_m or []:
            old_id = item.get("merchant_id")
            new_id = self.mapping.merchants.get(old_id)
            if not new_id:
                name = (item.get("merchant_name") or "").strip()
                if name:
                    merchant = self._match_merchant_by_name(name)
                    new_id = merchant.id if merchant else None
            if not new_id:
                continue
            exists = self.db.query(UserMerchantFavorite).filter(
                UserMerchantFavorite.user_id == self.user_id,
                UserMerchantFavorite.merchant_id == new_id,
            ).first()
            if exists:
                continue
            self.db.add(UserMerchantFavorite(user_id=self.user_id, merchant_id=new_id))
            imported_m += 1
        self.result.stats["user_merchant_favorites"] = imported_m
```

在导入执行顺序中（`self._import_user_places(collection)` 之后）追加：

```python
            cb("导入收藏", 0, 0, "正在导入收藏…")
            self._import_user_favorites(collection)
```

- [ ] **Step 7: 运行测试确认通过 + 回归导出测试**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/services/test_favorites_lifecycle.py -v`
Expected: PASS

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/services/test_export_packaging.py tests/services/test_export_serializers.py tests/services/test_export_reachability.py tests/services/test_export_importer_permissions.py -v`
Expected: 与基线一致（新增 extended/counts 条目不破坏既有断言；若有断言写死清单，按新事实更新）

- [ ] **Step 8: 提交**

```bash
git add backend/app/services/export/reachability.py backend/app/services/export/serializers.py backend/app/services/export/packaging.py backend/app/services/importer/importers/export.py backend/tests/services/test_favorites_lifecycle.py
git commit -m "feat(favorites): 导出导入包含收藏（原料/商品/菜谱 + 商家），名字两遍法回填"
```

---

### Task 6: web 通用件（useFavorites + FavoriteButton）+ 商家页替换

**Files:**
- Create: `frontend/src/composables/useFavorites.ts`
- Create: `frontend/src/components/common/FavoriteButton.vue`
- Modify: `frontend/src/views/data/MerchantsView.vue`（487-489、646-682、101-113、241-246、276-282 五处）
- Modify: `frontend/src/locales/{zh-CN,en-US,ar}.json`

**Interfaces:**
- Produces:
  - `useFavorites(entityType: 'ingredient' | 'product' | 'recipe' | 'merchant')` → `{ ids: Ref<Set<number>>, load(): Promise<void>, isFavorite(id): boolean, toggle(id): Promise<boolean> }`（`toggle` 成功返回新状态，失败抛错并已回滚）。
  - `<FavoriteButton :active="boolean" @toggle="..." />`
  - i18n 键：`favorites.favorite / favorites.unfavorite / favorites.favorited / favorites.unfavorited / favorites.favoriteFailed / favorites.unfavoriteFailed`。
- 后续 web 任务全部消费这两个通用件。

- [ ] **Step 1: 写 composable**

创建 `frontend/src/composables/useFavorites.ts`：

```ts
import { ref } from 'vue'
import { api } from '@/api'

export type FavoriteEntityType = 'ingredient' | 'product' | 'recipe' | 'merchant'

function listPath(t: FavoriteEntityType) {
  return t === 'merchant' ? '/merchants/favorites' : `/favorites/${t}`
}

function itemPath(t: FavoriteEntityType, id: number) {
  return t === 'merchant' ? `/merchants/${id}/favorite` : `/favorites/${t}/${id}`
}

/** 收藏集合（乐观更新 + 失败回滚）。进页面调用 load()，切换调用 toggle()。 */
export function useFavorites(entityType: FavoriteEntityType) {
  const ids = ref<Set<number>>(new Set())
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      const rows: any[] = await api.get(listPath(entityType))
      ids.value = new Set((Array.isArray(rows) ? rows : []).map((r) => r.id))
    } catch (e: any) {
      console.error(`Failed to load ${entityType} favorites`, e)
    } finally {
      loading.value = false
    }
  }

  function isFavorite(id: number) {
    return ids.value.has(id)
  }

  /** 返回切换后的状态；失败时已回滚并抛出（调用方负责提示） */
  async function toggle(id: number): Promise<boolean> {
    const wasFav = ids.value.has(id)
    const next = new Set(ids.value)
    if (wasFav) next.delete(id)
    else next.add(id)
    ids.value = next
    try {
      if (wasFav) await api.delete(itemPath(entityType, id))
      else await api.post(itemPath(entityType, id))
      return !wasFav
    } catch (e) {
      const rollback = new Set(ids.value)
      if (wasFav) rollback.add(id)
      else rollback.delete(id)
      ids.value = rollback
      throw e
    }
  }

  return { ids, loading, load, isFavorite, toggle }
}
```

- [ ] **Step 2: 写组件**

创建 `frontend/src/components/common/FavoriteButton.vue`：

```vue
<template>
  <v-btn
    :icon="active ? 'mdi-heart' : 'mdi-heart-outline'"
    :size="size"
    variant="text"
    :color="active ? 'error' : undefined"
    :title="active ? t('favorites.unfavorite') : t('favorites.favorite')"
    :aria-label="active ? t('favorites.unfavorite') : t('favorites.favorite')"
    @click.stop="$emit('toggle')"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

withDefaults(defineProps<{ active: boolean; size?: 'x-small' | 'small' | 'default' | 'large' }>(), {
  size: 'small',
})
defineEmits<{ (e: 'toggle'): void }>()

const { t } = useI18n()
</script>
```

- [ ] **Step 3: 加 i18n 键（三语）**

在 `frontend/src/locales/zh-CN.json` 顶层（按字母序就近，例如放在 `"favorites"` 的拼音位置 / 或与既有 `"merchants"` 相邻均可，保持三份一致）追加：

```json
  "favorites": {
    "title": "我的收藏",
    "favorite": "收藏",
    "unfavorite": "取消收藏",
    "favorited": "已收藏",
    "unfavorited": "已取消收藏",
    "favoriteFailed": "收藏失败",
    "unfavoriteFailed": "取消收藏失败",
    "loadFailed": "加载收藏失败",
    "onlyFavorites": "只看收藏",
    "empty": "暂无收藏",
    "tabIngredients": "原料",
    "tabProducts": "商品",
    "tabRecipes": "菜谱",
    "tabMerchants": "商家"
  },
```

`en-US.json` 对应英文（title: "My Favorites"，onlyFavorites: "Only favorites"，tab*: "Ingredients/Products/Recipes/Merchants"，empty: "No favorites yet"，loadFailed: "Failed to load favorites"）；`ar.json` 对应阿拉伯语（可从既有 `merchants.favorite` 等键的既有译文复用措辞：`إضافة للمفضلة / إزالة من المفضلة / مفضلتي فقط`，title 用「مفضلاتي」，tab* 复用既有 `nav.products` / `nav.ingredients` / `nav.recipes` / `nav.merchants` 的既有译文）。

Run: `cd frontend && npm run check:i18n && npm run check:i18n:sources`
Expected: `check:i18n` PASS（三语键树一致）；`check:i18n:sources` PASS（新键已全部在源码中被使用——Task 6 Step 4 之后才会被用上，故本步可以先只跑 `check:i18n`，`sources` 在 Step 5 之后跑）

- [ ] **Step 4: 替换 MerchantsView 三处内联实现**

`frontend/src/views/data/MerchantsView.vue`：

1. 删除 `const favoriteIds = ref<Set<number>>(new Set())`（487-488 行区域），改为：

```ts
import { useFavorites } from '@/composables/useFavorites'
import FavoriteButton from '@/components/common/FavoriteButton.vue'
// （放在既有 import 区）
const { ids: favoriteIds, load: loadFavorites, toggle: toggleFavoriteRaw } = useFavorites('merchant')
```

2. 删除原 `loadFavorites`（646-654）与 `toggleFavorite`（656-682）两个函数，替换为：

```ts
const toggleFavorite = async (id: number) => {
  const wasFav = favoriteIds.value.has(id)
  try {
    await toggleFavoriteRaw(id)
    notify(wasFav ? t('merchants.unfavorited') : t('merchants.favorited'), wasFav ? 'info' : 'success')
    if (favoritesOnly.value) {
      loadMerchants()
    }
  } catch (e: any) {
    notify(getErrorMessage(e, wasFav ? t('merchants.unfavoriteFailed') : t('merchants.favoriteFailed')), 'error')
  }
}
```

3. 三处心形 UI（101-113、241-246、276-282）改为使用组件，例如卡片网格处：

```vue
                  <FavoriteButton :active="favoriteIds.has(item.id)" @toggle="toggleFavorite(item.id)" />
```

列表项菜单内（两处）：

```vue
                        <v-list-item
                          :prepend-icon="favoriteIds.has(item.id) ? 'mdi-heart' : 'mdi-heart-outline'"
                          :base-color="favoriteIds.has(item.id) ? 'error' : undefined"
                          :title="favoriteIds.has(item.id) ? t('merchants.unfavorite') : t('merchants.favorite')"
                          @click="toggleFavorite(item.id)"
                        />
```

保持原样（菜单项视觉上更适合 `v-list-item`；只有卡片按钮换成组件）。此处**必须**在改完后实机验证三处心形可点、状态正确。

- [ ] **Step 5: 构建验证 + 提交**

Run: `cd frontend && npm run build && npm run check:i18n && npm run check:i18n:sources`
Expected: 全部 PASS（记录 `sources` 的新键数，供后续任务对照）

```bash
git add frontend/src/composables/useFavorites.ts frontend/src/components/common/FavoriteButton.vue frontend/src/views/data/MerchantsView.vue frontend/src/locales/zh-CN.json frontend/src/locales/en-US.json frontend/src/locales/ar.json
git commit -m "feat(favorites): useFavorites composable + FavoriteButton，商家收藏迁移到通用件"
```

---

### Task 7: web 三个列表页 + 三个详情页接入

**Files:**
- Modify: `frontend/src/views/data/ProductsView.vue`（529-566 筛选器、751-798 请求、83-92 / 150-153 行区插心形、110-120 卡片结构）
- Modify: `frontend/src/views/data/IngredientsView.vue`（445-469、568-609、73-88、139-148）
- Modify: `frontend/src/views/recipes/RecipesView.vue`（382-426、497-548、81-97）
- Modify: `frontend/src/views/products/ProductDetail.vue`（12-29 app-bar append）
- Modify: `frontend/src/views/ingredients/IngredientDetail.vue`（12-29）
- Modify: `frontend/src/views/recipes/RecipeDetail.vue`（14-99）

**Interfaces:**
- Consumes: `useFavorites` / `FavoriteButton` / `favorites.*` 键（Task 6）、后端参数（Task 3）
- Produces: 三个主列表页默认携带 `favorites_first=true`；「只看收藏」开关携带 `favorites_only=true`。

- [ ] **Step 1: ProductsView**

1. script setup 中追加：

```ts
import { useFavorites } from '@/composables/useFavorites'
import FavoriteButton from '@/components/common/FavoriteButton.vue'

const { ids: favoriteIds, load: loadFavorites, toggle: toggleFavoriteRaw } = useFavorites('product')
const { notify } = useGlobalSnackbar()   // 若该文件已引入则跳过

const favoritesOnly = computed(() => requestFilters.value.favorites_only === true)

const onToggleFavorite = async (id: number) => {
  const wasFav = favoriteIds.value.has(id)
  try {
    await toggleFavoriteRaw(id)
    notify(wasFav ? t('favorites.unfavorited') : t('favorites.favorited'), wasFav ? 'info' : 'success')
    if (favoritesOnly.value) loadProducts()
  } catch (e: any) {
    notify(getErrorMessage(e, wasFav ? t('favorites.unfavoriteFailed') : t('favorites.favoriteFailed')), 'error')
  }
}
```

（若 `useGlobalSnackbar` 未引入，按 MerchantsView 的用法引入；`getErrorMessage` 通常已引入。）

2. `productFilters` 数组追加一项（放在 `brands` 与 `special_conditions` 之间）：

```ts
  {
    key: 'favorites_only',
    label: t('favorites.onlyFavorites'),
    type: 'toggle',
    minWidth: '140px',
  },
```

3. `loadProducts` 的 params 构建中追加：

```ts
    params.favorites_first = 'true'
    if (requestFilters.value.favorites_only === true) {
      params.favorites_only = 'true'
    }
```

4. `onMounted` 中调用 `loadFavorites()`（与既有初始化同处）。

5. 行内按键：
   - 移动端 `#append`（83-92 行）：在 `mdi-tag-plus` 按钮**之前**插入

```vue
              <FavoriteButton :active="favoriteIds.has(item.id)" @toggle="onToggleFavorite(item.id)" />
```

   - 桌面卡片 `v-card-actions`（150-153 行）：在 `<v-spacer />` 之后插入

```vue
              <FavoriteButton :active="favoriteIds.has(item.id)" @toggle="onToggleFavorite(item.id)" />
```

（`FavoriteButton` 内部已 `@click.stop`，不会触发卡片导航。）

- [ ] **Step 2: IngredientsView**

同 Step 1 结构（`useFavorites('ingredient')`、筛选项同键、`params.favorites_first = 'true'` 与 `favorites_only`）。注意该页**没有** `useGlobalSnackbar`，有本地 snackbar（`showSnackbar/snackbarText/snackbarColor`）——本任务统一改用 `useGlobalSnackbar`（与 Products 一致，避免两套提示并存；模板中既有的本地 `<v-snackbar>` 保留不动，互不影响）。图标 `FavoriteButton` 插入位置：移动端 `#append`（73-88）中 `mdi-tag-plus` 之前；桌面 `v-card-actions`（139-148）中 `<v-spacer />` 之后。

- [ ] **Step 3: RecipesView**

同结构（`useFavorites('recipe')`、筛选项同键）。该页无 snackbar —— 引入 `useGlobalSnackbar`（`import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'`）。`loadRecipes` 中 `params.favorites_first = 'true'`、`favorites_only` 同上。心形插入位置：卡片标题行（81-97 行）中，紧跟 `pendingName(recipe)` 之后：

```vue
            <FavoriteButton
              :active="favoriteIds.has(recipe.id)"
              class="ms-1"
              @toggle="onToggleFavorite(recipe.id)"
            />
```

- [ ] **Step 4: 三个详情页 app-bar 心形**

`ProductDetail.vue` / `IngredientDetail.vue`（结构同构）：

- script setup 追加：

```ts
import { useFavorites } from '@/composables/useFavorites'
import FavoriteButton from '@/components/common/FavoriteButton.vue'

const favorites = useFavorites('product')   // 原料页改 'ingredient'，菜谱页改 'recipe'
const entityId = computed(() => Number(route.params.id) || null)

onMounted(async () => { await favorites.load() })
```

（两个文件已有 `route`；若变量名不同按实际改。）

- 模板桌面端（`<template v-if="isDesktop">` 内第一个按钮之前）插入：

```vue
        <FavoriteButton
          v-if="entityId"
          :active="favorites.isFavorite(entityId)"
          @toggle="onToggleDetailFavorite"
        />
```

- 模板移动端菜单（`v-list` 第一项之前）插入：

```vue
          <v-list-item
            v-if="entityId"
            :prepend-icon="favorites.isFavorite(entityId) ? 'mdi-heart' : 'mdi-heart-outline'"
            :base-color="favorites.isFavorite(entityId) ? 'error' : undefined"
            :title="favorites.isFavorite(entityId) ? t('favorites.unfavorite') : t('favorites.favorite')"
            @click="onToggleDetailFavorite"
          />
```

- script 追加处理函数：

```ts
const onToggleDetailFavorite = async () => {
  if (!entityId.value) return
  const wasFav = favorites.isFavorite(entityId.value)
  try {
    await favorites.toggle(entityId.value)
    notify(wasFav ? t('favorites.unfavorited') : t('favorites.favorited'), wasFav ? 'info' : 'success')
  } catch (e: any) {
    notify(getErrorMessage(e, wasFav ? t('favorites.unfavoriteFailed') : t('favorites.favoriteFailed')), 'error')
  }
}
```

（两页已有 `notify`/`showMessage` 之类提示工具与 `getErrorMessage`；按文件实际命名接入，**改前先 grep 该文件内已有的提示函数名**。`RecipeDetail.vue` 有 BOM，编辑时保持文件首字节不变。）

- [ ] **Step 5: 构建验证**

Run: `cd frontend && npm run build && npm run check:i18n:sources && npx tsc --noEmit 2>&1 | tail -5`
Expected: build PASS；sources PASS；tsc 错误数与基线持平（约 137 条噪音，均为既有 `.vue` 解析噪音）

- [ ] **Step 6: 实机验证（必做）**

在运行中的 `http://localhost:5173` 上逐项点验：
1. 商品/原料/菜谱列表：心形可收藏/取消，刷新后状态保持；
2. 「只看收藏」筛选只显示收藏项（与另一筛选条件叠加也正确）；
3. 收藏项默认置顶（取消收藏后回到原位）；
4. 三个详情页心形工作正常；
5. 商家页三处心形仍正常（回归 Task 6 的替换）。

- [ ] **Step 7: 提交**

```bash
git add frontend/src/views/data/ProductsView.vue frontend/src/views/data/IngredientsView.vue frontend/src/views/recipes/RecipesView.vue frontend/src/views/products/ProductDetail.vue frontend/src/views/ingredients/IngredientDetail.vue frontend/src/views/recipes/RecipeDetail.vue
git commit -m "feat(favorites): 商品/原料/菜谱列表与详情接入收藏（筛选 + 置顶 + 心形）"
```

---

### Task 8: web「我的收藏」聚合页 + 路由 + 导航

**Files:**
- Create: `frontend/src/views/favorites/FavoritesView.vue`
- Modify: `frontend/src/router/index.ts`（在 `data/merchants` 段之后插入）
- Modify: `frontend/src/components/layout/AppLayout.vue`（导航 `<v-list>` 内追加一项）
- Modify: `frontend/src/locales/{zh-CN,en-US,ar}.json`（`nav.favorites`、`routes.favorites`）

**Interfaces:**
- Consumes: `GET /api/v1/favorites`（Task 2）
- Produces: 路由 `/favorites`（name: `favorites`）。

- [ ] **Step 1: 写页面**

创建 `frontend/src/views/favorites/FavoritesView.vue`：

```vue
<template>
  <v-container>
    <div class="d-flex align-center ga-2 mb-4">
      <h1 class="text-h6">{{ t('favorites.title') }}</h1>
      <v-spacer />
      <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
    </div>

    <v-tabs v-model="activeTab" density="comfortable" class="mb-2">
      <v-tab value="ingredients">{{ t('favorites.tabIngredients') }}</v-tab>
      <v-tab value="products">{{ t('favorites.tabProducts') }}</v-tab>
      <v-tab value="recipes">{{ t('favorites.tabRecipes') }}</v-tab>
      <v-tab value="merchants">{{ t('favorites.tabMerchants') }}</v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <v-window-item v-for="key in tabs" :key="key" :value="key">
        <v-list v-if="currentItems(key).length" lines="two">
          <v-list-item
            v-for="item in currentItems(key)"
            :key="item.id"
            :title="item.name"
            :subtitle="item.subtitle || undefined"
            @click="goDetail(key, item.id)"
          >
            <template #append>
              <FavoriteButton :active="true" @toggle="unfavorite(key, item.id)" />
            </template>
          </v-list-item>
        </v-list>
        <div v-else-if="!loading" class="text-center py-10 text-medium-emphasis">
          <v-icon size="64" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="mt-3">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>
    </v-window>
  </v-container>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { getErrorMessage } from '@/utils/errorHandler'
import FavoriteButton from '@/components/common/FavoriteButton.vue'

const { t } = useI18n()
const router = useRouter()
const { notify } = useGlobalSnackbar()

const tabs = ['ingredients', 'products', 'recipes', 'merchants'] as const
type TabKey = (typeof tabs)[number]

const activeTab = ref<TabKey>('ingredients')
const loading = ref(false)
const grouped = ref<Record<TabKey, any[]>>({
  ingredients: [], products: [], recipes: [], merchants: [],
})

function currentItems(key: TabKey): any[] {
  return grouped.value[key] || []
}

async function load() {
  loading.value = true
  try {
    const payload: any = await api.get('/favorites')
    grouped.value = {
      ingredients: payload.ingredients || [],
      products: payload.products || [],
      recipes: payload.recipes || [],
      merchants: payload.merchants || [],
    }
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.loadFailed')), 'error')
  } finally {
    loading.value = false
  }
}

const detailPath: Record<TabKey, (id: number) => string> = {
  ingredients: (id) => `/data/ingredients/${id}`,
  products: (id) => `/data/products/${id}`,
  recipes: (id) => `/recipes/${id}`,
  merchants: (id) => `/data/merchants/${id}`,
}

const deletePath: Record<TabKey, (id: number) => string> = {
  ingredients: (id) => `/favorites/ingredient/${id}`,
  products: (id) => `/favorites/product/${id}`,
  recipes: (id) => `/favorites/recipe/${id}`,
  merchants: (id) => `/merchants/${id}/favorite`,
}

function goDetail(key: TabKey, id: number) {
  router.push(detailPath[key](id))
}

async function unfavorite(key: TabKey, id: number) {
  try {
    await api.delete(deletePath[key](id))
    grouped.value = {
      ...grouped.value,
      [key]: currentItems(key).filter((it) => it.id !== id),
    }
    notify(t('favorites.unfavorited'), 'info')
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.unfavoriteFailed')), 'error')
  }
}

onMounted(load)
</script>
```

- [ ] **Step 2: 路由与导航**

`frontend/src/router/index.ts`：在 `data/merchants/:id` 之后插入（与相邻条目同构）：

```ts
        {
          path: 'favorites',
          name: 'favorites',
          component: () => import('@/views/favorites/FavoritesView.vue'),
          meta: { titleKey: 'routes.favorites' },
        },
```

`frontend/src/components/layout/AppLayout.vue`：在主 `<v-list density="compact" nav>` 中「商家」一项之后插入：

```vue
        <v-list-item prepend-icon="mdi-heart" :title="t('nav.favorites')" to="/favorites" />
```

- [ ] **Step 3: i18n（三语）**

`nav.favorites`：zh `我的收藏` / en `Favorites` / ar `مفضلاتي`。
`routes.favorites`：zh `我的收藏` / en `Favorites` / ar `مفضلاتي`。

Run: `cd frontend && npm run check:i18n && npm run check:i18n:sources`
Expected: PASS（记录新键数）

- [ ] **Step 4: 实机验证**

在 `http://localhost:5173/favorites` 点验：四个 tab 均有数据（先在 Task 7 的页面收藏若干项）；点击项跳详情；心形取消后从列表消失；空态正常（清空某类收藏）。

- [ ] **Step 5: 构建验证 + 提交**

Run: `cd frontend && npm run build`

```bash
git add frontend/src/views/favorites/FavoritesView.vue frontend/src/router/index.ts frontend/src/components/layout/AppLayout.vue frontend/src/locales/zh-CN.json frontend/src/locales/en-US.json frontend/src/locales/ar.json
git commit -m "feat(favorites): 「我的收藏」聚合页 + 路由与导航"
```

---

### Task 9: 本地离线模式（IndexedDB + handlers + 列表参数 + 导出导入）

**Files:**
- Modify: `frontend/src/api/local/database.ts`（类型 + DB_VERSION 3→4 + v4 建 store）
- Create: `frontend/src/api/local/handlers/favorites.ts`
- Modify: `frontend/src/api/local/proxy.ts`
- Modify: `frontend/src/api/local/handlers/products.ts` / `ingredients.ts` / `recipes.ts`
- Modify: `frontend/src/api/local/handlers/exportImport.ts`
- Modify: `frontend/src/utils/localErrors` 对应的三语 `localErrors.*` 键（检查是否已有可复用键，缺失则新增）

**Interfaces:**
- Consumes: 云端同构 URL（`/favorites`、`/favorites/:type`、`/favorites/:type/:id`）
- Produces: 本地模式下与云端一致的收藏行为。

- [ ] **Step 1: 数据层**

`frontend/src/api/local/database.ts`：

1. 类型表追加：

```ts
  'user_favorites': {
    key: number
    value: any
    indexes: { 'by_entity_key': string }
  }
```

2. `DB_VERSION` 由 3 改为 4。
3. 在 `upgrade` 回调中 v3 块之后追加：

```ts
      // v4: 收藏（原料/商品/菜谱；商家收藏沿用 merchant_favorites）
      if (oldVersion < 4) {
        const favStore = db.createObjectStore('user_favorites', { keyPath: 'id', autoIncrement: true })
        favStore.createIndex('by_entity_key', 'entity_key')
      }
```

行结构：`{ id, entity_type, entity_id, entity_key: `${entity_type}:${entity_id}`, created_at }`。

- [ ] **Step 2: handlers**

创建 `frontend/src/api/local/handlers/favorites.ts`：

```ts
// Favorites handler — 原料/商品/菜谱收藏（本地模式，云端 URL 同构）。

import { getAll, addOne, deleteOne, getById, getByIndex } from '../database'
import { localError } from '../../../utils/localErrors'

const TYPES = ['ingredient', 'product', 'recipe']

function itemsPath(type: string, id: number): string {
  if (type === 'ingredient') return `/data/ingredients/${id}`
  if (type === 'product') return `/data/products/${id}`
  return `/recipes/${id}`
}

async function loadRows(type: string): Promise<any[]> {
  const favs = await getAll('user_favorites')
  return favs
    .filter((f: any) => f.entity_type === type)
    .sort((a: any, b: any) => ((b.created_at || '') > (a.created_at || '') ? 1 : -1))
}

async function toItems(type: string): Promise<any[]> {
  const rows = await loadRows(type)
  const items: any[] = []
  for (const row of rows) {
    if (type === 'merchant') continue
    const storeName = type === 'ingredient' ? 'ingredients' : type === 'product' ? 'products' : 'recipes'
    const entity = await getById(storeName, row.entity_id)
    if (!entity || entity.is_active === false) continue
    if (type === 'ingredient') {
      items.push({ id: entity.id, name: entity.name, subtitle: null, image: null })
    } else if (type === 'product') {
      let subtitle = null
      if (entity.ingredient_id) {
        const ing = await getById('ingredients', entity.ingredient_id)
        subtitle = ing?.name || null
      }
      items.push({ id: entity.id, name: entity.name, subtitle, image: entity.image_url || null })
    } else {
      items.push({
        id: entity.id,
        name: entity.name,
        subtitle: entity.category || null,
        image: (entity.images || [])[0] || null,
      })
    }
  }
  return items
}

export async function listAll(_params: Record<string, string>): Promise<any> {
  return {
    ingredients: await toItems('ingredient'),
    products: await toItems('product'),
    recipes: await toItems('recipe'),
    merchants: await listMerchantFavorites(),
  }
}

async function listMerchantFavorites(): Promise<any[]> {
  const [favorites, allMerchants] = await Promise.all([
    getAll('merchant_favorites'),
    getAll('merchants'),
  ])
  const merchantMap = new Map(allMerchants.map((m: any) => [m.id, m]))
  return favorites
    .map((f: any) => merchantMap.get(f.merchant_id))
    .filter((m: any) => m != null && m.is_active !== false)
}

export async function listByType(params: Record<string, string>): Promise<any> {
  const type = params.type
  if (!TYPES.includes(type)) throw localError('favoriteUnsupportedType', 400, { type })
  return await toItems(type)
}

export async function addFavorite(params: Record<string, string>): Promise<any> {
  const type = params.type
  const entityId = parseInt(params.id)
  if (!TYPES.includes(type)) throw localError('favoriteUnsupportedType', 400, { type })
  const storeName = type === 'ingredient' ? 'ingredients' : type === 'product' ? 'products' : 'recipes'
  const entity = await getById(storeName, entityId)
  if (!entity || entity.is_active === false) {
    throw localError('favoriteEntityNotFound', 404, { id: entityId })
  }
  const entityKey = `${type}:${entityId}`
  const existing = await getByIndex('user_favorites', 'by_entity_key', entityKey)
  if (existing.length > 0) return { ok: true }
  await addOne('user_favorites', {
    entity_type: type,
    entity_id: entityId,
    entity_key: entityKey,
    created_at: new Date().toISOString(),
  })
  return { ok: true }
}

export async function removeFavorite(params: Record<string, string>): Promise<any> {
  const type = params.type
  const entityId = parseInt(params.id)
  const entityKey = `${type}:${entityId}`
  const existing = await getByIndex('user_favorites', 'by_entity_key', entityKey)
  for (const row of existing) {
    await deleteOne('user_favorites', row.id)
  }
  return { ok: true }
}
```

（说明：`localError(code, status = 400, params = {})` 是既有签名，`params` 会作为 `t('localErrors.<code>', params)` 的插值；`itemsPath` 若最终未用到可删。）

`localErrors` 新增两个键（三语）：`favoriteUnsupportedType`（zh「不支持的收藏类型」/ en "Unsupported favorite type" / ar 对应阿语）、`favoriteEntityNotFound`（zh「收藏对象不存在或已删除」/ en "Favorite target not found" / ar 对应阿语）。该区块在 `frontend/src/locales/zh-CN.json:1191` 起（三语同构），在其内部追加两个键（阿语措辞参照同区块既有条目）。

- [ ] **Step 3: proxy 路由**

`frontend/src/api/local/proxy.ts`：在 products 段附近（保持「精确路径在前」）追加：

```ts
// ---- Favorites ----
addRoute('/favorites', { get: favorites.listAll })
addRoute('/favorites/:type', { get: favorites.listByType })
addRoute('/favorites/:type/:id', { post: favorites.addFavorite, delete: favorites.removeFavorite })
```

并 import `favorites`（与其它 `import * as xxx from './handlers/xxx'` 同处）。

- [ ] **Step 4: 列表参数（products / ingredients / recipes）**

三个 handler 的 list 函数统一追加（以 `products.ts` 的 `listEntity` 为例，ingredients / recipes 同构，注意 entity 过滤键与 id 字段名）：

```ts
  const favoritesOnly = isTruthy(query?.favorites_only)
  const favoritesFirst = isTruthy(query?.favorites_first)
  let favoriteIdSet: Set<number> | null = null
  if (favoritesOnly || favoritesFirst) {
    const favRows = await getAll('user_favorites')
    favoriteIdSet = new Set(
      favRows
        .filter((f: any) => f.entity_type === 'product' && f.entity_id != null)
        .map((f: any) => f.entity_id),
    )
  }
```

在 `filtered` 过滤链之后（排序之前或之后都可，但**必须**在 `resolvePagination` 切片之前）：

```ts
  if (favoritesOnly && favoriteIdSet) {
    filtered = filtered.filter((p: any) => favoriteIdSet!.has(p.id))
  }
```

在排序之后、分页之前：

```ts
  if (favoritesFirst && favoriteIdSet && favoriteIdSet.size > 0) {
    const favs = filtered.filter((p: any) => favoriteIdSet!.has(p.id))
    const rest = filtered.filter((p: any) => !favoriteIdSet!.has(p.id))
    filtered = [...favs, ...rest]
  }
```

（ingredients.ts 用 `entity_type === 'ingredient'`，recipes.ts 用 `'recipe'`；`getAll` 均已 import。）

- [ ] **Step 5: 导出导入白名单**

`frontend/src/api/local/handlers/exportImport.ts`：

1. `EXPORT_STORES` 追加 `'user_favorites',`（`'merchant_favorites'` 一行之后）。
2. `FILE_STORE_MAP` 追加：

```ts
  'user_favorites.json': 'user_favorites',
  'user_merchant_favorites.json': 'merchant_favorites',
```

- [ ] **Step 6: 构建 + 实机验证（本地模式）**

Run: `cd frontend && npm run build && npm run check:i18n:sources`

实机（用本地模式启动前端，`VITE_STORAGE_MODE=local` 的既有方式）：收藏/取消三列表 + 详情、只看收藏、置顶、聚合页、刷新后保持（IndexedDB）；导出 ZIP 含 `user_favorites.json`，再导入不报错且不重复。

- [ ] **Step 7: 提交**

```bash
git add frontend/src/api/local/database.ts frontend/src/api/local/handlers/favorites.ts frontend/src/api/local/proxy.ts frontend/src/api/local/handlers/products.ts frontend/src/api/local/handlers/ingredients.ts frontend/src/api/local/handlers/recipes.ts frontend/src/api/local/handlers/exportImport.ts frontend/src/locales/zh-CN.json frontend/src/locales/en-US.json frontend/src/locales/ar.json
git commit -m "feat(favorites): 本地离线模式收藏（IndexedDB store + handlers + 列表参数 + 导出导入）"
```

---

### Task 10: 全量验证、要点记录、master → feat 合并

**Files:**
- Modify: `AGENTS.md`（索引追加一行）
- Create: `agent_doc/FEATURE_收藏.md`
- （合并操作，无文件改动）

- [ ] **Step 1: 后端全量回归**

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/ -x -q 2>&1 | tail -15`
Expected: 失败集合与既有基线一致（不新增；既有失败清单见 memory「后端既有 pytest 失败清单」——运行方式敏感，先与基线对照再定责）

Run: `cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest tests/test_user_favorites_api.py tests/services/test_favorites_lifecycle.py -v`
Expected: 全 PASS

- [ ] **Step 2: 前端全量验证**

Run: `cd frontend && npm run build && npm run check:i18n && npm run check:i18n:sources && npm run test:utils`
Expected: 全 PASS（记录 `sources` 键数）
Run: `cd frontend && npx tsc --noEmit 2>&1 | tail -3`
Expected: 与基线持平（约 137 条）

- [ ] **Step 3: 实机端到端清单（云端模式）**

1. 收藏/取消：商品/原料/菜谱列表 + 详情 + 商家列表（回归）；
2. 只看收藏筛选（三类列表）与收藏置顶；
3. 「我的收藏」页四 tab、跳转、取消收藏；
4. 导出 ZIP 含 `user_favorites.json` 与 `user_merchant_favorites.json`；
5. 导入一份导出的 ZIP（同库）→ 无报错、收藏不重复。

- [ ] **Step 4: 记录要点**

1. 创建 `agent_doc/FEATURE_收藏.md`：写清数据模型（多态链接表 + 唯一约束）、端点清单与参数、合并/导出导入口径（删除源收藏 + 快照回滚；两遍法按名回填）、三端实现位置、测试与验证结论、经验教训。
2. 在 `AGENTS.md` 的「项目索引」区追加一行指向该文档（含一句摘要）；若本次产生值得记录的修复/坑（例如「共用端点排序参数化」「列表置顶不能改默认排序」的再次确认），按「最新修复记录」格式追加（保留最近 10 条）。

- [ ] **Step 5: 提交文档**

```bash
git add AGENTS.md agent_doc/FEATURE_收藏.md
git commit -m "docs: 记录收藏功能要点（阶段 1 完成）"
```

- [ ] **Step 6: 合并到 feat/mobile-app**

```bash
git checkout feat/mobile-app
git merge master --no-edit
# 若 AGENTS.md 冲突：两边记录区都保留（master 的收藏条目 + feat 的移动端条目），其余冲突按「union」处理
git checkout master   # 切回工作分支（保持会话起始状态）
```

Expected: 合并完成且 `git status` 干净；feat/mobile-app 上可见本次所有提交（供后续移动端计划使用）。

---

## 计划自审记录

- **Spec 覆盖**：§3.1 数据模型（Task 1）、§3.2 API 与列表参数（Task 2/3）、§3.3 合并 + 导出导入（Task 4/5，含决策 #16 的「商家收藏一并补进导出」）、§3.4 web（Task 6/7/8，含本地模式 Task 9）、§3.5 移动端（**不在本计划范围**，另出计划）、§3.6 偏好信号（阶段 2 消费，本计划只保证数据可查）、§3.7 测试（各任务内 + Task 10 汇总）。
- **类型一致性**：`UserFavorite` 字段名在 Task 1 定义，Task 2/3/4/5 全部沿用 `entity_type / entity_id / user_id`；web 侧统一 `favorites_first / favorites_only`（后端参数名同）；`FavoriteItem` 形状在三处消费点一致（`id / name / subtitle / image`）。
- **Review Focus 对应**：软删（Task 2 测试）、幂等/唯一约束（Task 1 测试 + Task 2 幂等断言）、叠加筛选 total 一致（Task 3 测试）、排序稳定（Task 3 断言非收藏项序列不变）、导入跳过（Task 5 实现含跳过分支，实机清单第 5 项覆盖）。
