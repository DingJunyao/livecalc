# Barcode Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide barcode camera input, backend product lookup with configurable providers and cache, and product creation fallback in web and mobile price workflows.

**Architecture:** One authenticated backend endpoint resolves a barcode against local product fields, the cache table, then configured providers in priority order. Web and mobile clients never call third-party barcode APIs directly; they consume this endpoint. Admin configuration is persisted as `system_config.key = barcode_service_config`; provider credentials are masked on read and retained when a masked sentinel is submitted.

**Tech Stack:** FastAPI, SQLAlchemy, Alembic, `httpx`, Vue 3/Vuetify, `@zxing/browser`, Flutter Riverpod/GoRouter, `mobile_scanner`.

---

## Preconditions

- [ ] Use existing `D:\code\live_calc-master` worktree for master work. It is an isolated linked worktree; do not create another.
- [ ] Fast-forward master to `origin/master` before implementation because the current checkout was observed behind by one commit.
- [ ] Cherry-pick design commit `166ba15` plus the plan commit from `feat/mobile-app` into master.
- [ ] Do not start dev servers. Run backend tests with `uv run pytest`; frontend build with `npm run build`; mobile checks with `flutter test` and `flutter analyze`.
- [ ] TDD applies to backend service/API logic and mobile repository/model logic. Vue has no test runner in this repo, so its verification is TypeScript/build plus backend/local-handler contract tests.

### Task 1: Cache model and database scripts

**Files:**
- Create: `backend/app/models/barcode_lookup_cache.py`
- Modify: `backend/app/models/__init__.py`
- Create: `backend/alembic/versions/20260821_0001_add_barcode_lookup_cache.py`
- Create: `backend/scripts/sql/20260821_barcode_lookup_cache_sqlite.sql`
- Create: `backend/scripts/sql/20260821_barcode_lookup_cache_mysql.sql`
- Create: `backend/scripts/sql/20260821_barcode_lookup_cache_postgres.sql`
- Test: `backend/tests/models/test_barcode_lookup_cache.py`

- [ ] **Step 1: Write failing schema test**

```python
from app.core.database import Base


def test_barcode_lookup_cache_columns():
    columns = Base.metadata.tables["barcode_lookup_cache"].columns
    assert columns["barcode"].primary_key
    assert not columns["barcode"].nullable
    assert not columns["payload"].nullable
    assert not columns["source"].nullable
    assert not columns["fetched_at"].nullable
    assert not columns["expires_at"].nullable
```

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/models/test_barcode_lookup_cache.py -q`

Expected: `KeyError: 'barcode_lookup_cache'`.

- [ ] **Step 3: Implement model and scripts**

Create:

```python
from sqlalchemy import Column, DateTime, String, Text
from sqlalchemy.sql import func

from app.core.database import Base


class BarcodeLookupCache(Base):
    __tablename__ = "barcode_lookup_cache"

    barcode = Column(String(50), primary_key=True)
    payload = Column(Text, nullable=False)
    source = Column(String(100), nullable=False)
    fetched_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
```

The Alembic upgrade creates the same five columns and `ix_barcode_lookup_cache_expires_at`; downgrade drops the table. SQL scripts create/drop the same table for SQLite, MySQL, PostgreSQL, and the PostGIS deployment uses the same PostgreSQL script because the table is not spatial.

- [ ] **Step 4: Verify GREEN and commit**

Run: `uv run pytest tests/models/test_barcode_lookup_cache.py -q`

Expected: 1 passed.

Commit: `git add backend/app/models/barcode_lookup_cache.py backend/app/models/__init__.py backend/alembic/versions/20260821_0001_add_barcode_lookup_cache.py backend/scripts/sql/20260821_barcode_lookup_cache_*.sql backend/tests/models/test_barcode_lookup_cache.py && git commit -m "feat: add barcode lookup cache"`

### Task 2: Provider configuration and request adapters

**Files:**
- Create: `backend/app/services/barcode_lookup.py`
- Test: `backend/tests/services/test_barcode_providers.py`

- [ ] **Step 1: Write failing provider tests**

Cover these five behaviors with real service functions and a patched `httpx.Client.get`:

```python
def test_open_foodfacts_maps_product():
    service = ServiceConfig(id="off", type="openfoodfacts", enabled=True)
    provider = BarcodeProvider(service)
    result = provider.parse({"status": 1, "product": {
        "product_name": "Milk", "brands": "Brand", "quantity": "500 ml",
        "image_url": "https://example.test/milk.jpg"
    }})
    assert result and result["name"] == "Milk"


def test_mxnzp_maps_data():
    assert parse_mxnzp({"code": 200, "data": {"goodsName": "Milk", "brandName": "Brand"}})["name"] == "Milk"


def test_yunji_maps_data():
    assert parse_yunji({"status": 200, "data": {"ItemName": "Milk", "BrandName": "Brand"}})["name"] == "Milk"


def test_custom_jsonpath_and_url():
    service = custom_service()
    assert jsonpath({"data": {"items": [{"name": "Milk"}]}}, "$.data.items[0].name") == "Milk"
    assert build_url("https://api.test/g/{barcode}", "123") == "https://api.test/g/123"


def test_reject_private_custom_url():
    with pytest.raises(ValueError):
        validate_public_http_url("http://127.0.0.1/api?barcode={barcode}")
```

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/services/test_barcode_providers.py -q`

Expected: import failure because `app.services.barcode_lookup` does not exist.

- [ ] **Step 3: Implement minimal provider layer**

Public shapes:

```python
class ServiceConfig(BaseModel):
    id: str
    type: Literal["openfoodfacts", "mxnzp", "yunji", "custom"]
    enabled: bool = False
    timeout_seconds: float = Field(5, ge=0.1, le=30)
    name: str | None = None
    doc_url: HttpUrl | None = None
    app_id: str | None = None
    app_secret: str | None = None
    app_code: str | None = None
    url_template: str | None = None
    headers: dict[str, str] = {}
    mappings: dict[str, str] = {}


class BarcodeConfig(BaseModel):
    cache_ttl_minutes: int = Field(10080, ge=1, le=527040)
    services: list[ServiceConfig] = []


def default_config() -> dict: ...
def load_config(db: Session) -> BarcodeConfig: ...
def mask_config(config: BarcodeConfig) -> dict: ...
def merge_saved_secrets(saved: BarcodeConfig, incoming: dict) -> BarcodeConfig: ...
def validate_config(config: BarcodeConfig) -> None: ...
def lookup_with_provider(config: ServiceConfig, barcode: str, client: httpx.Client) -> dict | None: ...
```

Rules:
- Custom ids are prefixed `custom:` in response `source`; builtins use `openfoodfacts`, `mxnzp`, or `yunji`.
- Duplicate enabled service ids are rejected.
- Built-in endpoints and field mappings are fixed. mxnzp uses `app_id` and `app_secret`; Yunji sends `Authorization: APPCODE <app_code>`.
- Custom URL must be HTTP(S), contain `{barcode}`, use a bracket-safe template, and resolve to a public host. Reject loopback, private, link-local, unspecified, and multicast addresses.
- JSONPath supports only root-relative dot names, `[integer]`, and `['name']`; reject `..`, `*`, `(`, `)`, and filters.
- A provider hit requires a non-empty string name; transport errors, HTTP errors, malformed JSON, and misses return `None` with an error message retained by the caller.

- [ ] **Step 4: Verify GREEN and commit**

Run: `uv run pytest tests/services/test_barcode_providers.py -q`

Expected: all provider tests pass.

Commit: `git add backend/app/services/barcode_lookup.py backend/tests/services/test_barcode_providers.py && git commit -m "feat: add barcode providers"`

### Task 3: Resolver with cache and local priority

**Files:**
- Modify: `backend/app/services/barcode_lookup.py`
- Test: `backend/tests/services/test_barcode_resolver.py`

- [ ] **Step 1: Write failing resolver tests**

Create active `Ingredient`, `Product`, and optional `ProductBarcode` rows directly in the shared test DB. Use mocked provider calls.

Assertions:
- primary `Product.barcode` wins and response `source == "local"`;
- active `ProductBarcode.barcode` wins after primary miss;
- an unexpired cache hit is returned without provider calls;
- an expired cache row is replaced after a provider hit;
- provider miss returns `found=False`, empty product, and one error per enabled provider;
- provider hit is saved as normalized JSON with source and TTL-derived expiry.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/services/test_barcode_resolver.py -q`

Expected: `ImportError` for `resolve_barcode`.

- [ ] **Step 3: Implement resolver**

```python
@dataclass
class LookupOutcome:
    found: bool
    source: str | None
    product: dict | None
    errors: list[str]


def resolve_barcode(db: Session, barcode: str, client: httpx.Client | None = None) -> LookupOutcome: ...
def test_service(db: Session, config: BarcodeConfig, barcode: str, client: httpx.Client | None = None) -> LookupOutcome: ...
```

Normalize local and external payload to `barcode`, `name`, `brand`, `spec`, `manufacturer`, `image_url`, and `id` for local rows only. Strip values, ignore empty strings, and cache only provider hits.

- [ ] **Step 4: Verify GREEN and commit**

Run: `uv run pytest tests/services/test_barcode_providers.py tests/services/test_barcode_resolver.py -q`

Commit: `git add backend/app/services/barcode_lookup.py backend/tests/services/test_barcode_resolver.py && git commit -m "feat: resolve barcodes with cache"`

### Task 4: Unified API and admin configuration API

**Files:**
- Create: `backend/app/api/barcode_config.py`
- Modify: `backend/app/api/products_entity.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_barcode_lookup_api.py`

- [ ] **Step 1: Write failing API tests**

Using `as_admin` and the shared DB:

```python
def test_barcode_endpoint_requires_auth():
    r = client.get("/api/v1/products/entity/barcode/123")
    assert r.status_code == 401


def test_local_barcode_lookup(as_admin):
    r = client.get("/api/v1/products/entity/barcode/6900000000000")
    assert r.status_code == 200
    assert r.json() == {"found": True, "source": "local", "product": EXPECTED, "errors": []}


def test_miss_returns_404_body(as_admin):
    r = client.get("/api/v1/products/entity/barcode/not-found")
    assert r.status_code == 404
    assert r.json()["found"] is False
    assert isinstance(r.json()["errors"], list)
```

Also assert GET `/api/v1/admin/barcode-services` masks `app_secret`/`app_code`; PUT persists JSON in `system_config`, retains `***` secrets, validates private custom URLs with 400, and deletes cache rows; POST `/test` returns a sanitized result and calls only the selected provider.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/test_barcode_lookup_api.py -q`

Expected: lookup route and admin router do not exist.

- [ ] **Step 3: Implement APIs**

- Add `/products/entity/barcode/{barcode}` before numeric product routes in `products_entity.py`; it requires `get_current_user` and returns `LookupOutcome`, or `JSONResponse(status_code=404, content=asdict(outcome))` on miss.
- Add `/admin/barcode-services` with GET, PUT, and POST `/test`; all require `get_current_admin_user`.
- GET returns masked config. PUT merges `None`/`"***"` credential fields with saved values, validates, upserts `SystemConfig(key="barcode_service_config", value=config.model_dump(mode="json"))`, deletes all `BarcodeLookupCache` rows, and commits.
- POST `/test` accepts one complete service object and a barcode, never writes cache/config, and returns `{"found", "source", "product", "errors"}` without credentials.

- [ ] **Step 4: Verify GREEN, syntax, and commit**

Run:

```powershell
uv run pytest tests/models/test_barcode_lookup_cache.py tests/services/test_barcode_providers.py tests/services/test_barcode_resolver.py tests/test_barcode_lookup_api.py -q
uv run python -m py_compile app/api/products_entity.py app/api/barcode_config.py app/services/barcode_lookup.py
```

Commit: `git add backend/app/api/barcode_config.py backend/app/api/products_entity.py backend/app/main.py backend/tests/test_barcode_lookup_api.py && git commit -m "feat: expose barcode lookup services"`

### Task 5: Web admin page and local-mode contracts

**Files:**
- Create: `frontend/src/views/admin/BarcodeServicesView.vue`
- Modify: `frontend/src/router/index.ts`
- Modify: `frontend/src/views/admin/AdminDashboard.vue`
- Modify: `frontend/src/api/local/handlers/admin.ts`
- Modify: `frontend/src/api/local/handlers/products.ts`
- Modify: `frontend/src/api/local/proxy.ts`

- [ ] **Step 1: Implement page and routes**

- Add `/admin/barcode-services` lazy route and admin dashboard card/link.
- Render an ordered list of service cards. Built-ins are labeled Open Food Facts, mxnzp, and “云际（云 API 市场）”; never label Yunji as “阿里云”.
- Every built-in card exposes its apply/docs link: Open Food Facts `https://world.openfoodfacts.org/`, mxnzp `https://www.mxnzp.com/doc/detail?id=6`, Yunji `https://market.aliyun.com/detail/cmapi031448`.
- Controls: enabled switch, up/down priority buttons, timeout field, credential fields, test barcode and test button, add/delete custom service.
- Custom card fields: name, doc link, URL template, static headers, and five JSONPath mappings. Delete is a single confirmation dialog.
- Save sends only non-empty credential values; masked values are left untouched by backend/local merge logic.

- [ ] **Step 2: Add local handlers**

- `admin.getBarcodeServices`/`updateBarcodeServices` reuse `getConfigValue('barcode_service_config')`, defaults, masking, and credential merge.
- `admin.testBarcodeService` returns `{ok: false, errors: ['本地模式不支持外部条码服务连通性测试']}`.
- `products.lookupBarcode` checks main `products.barcode`, then active `product_barcodes.barcode`, and returns local/found-false only; it never fetches third parties or cache.
- Register exact routes before parameterized `/products/entity/:id`.

- [ ] **Step 3: Verify and commit**

Run: `npm run build`

Commit: `git add frontend/src/views/admin/BarcodeServicesView.vue frontend/src/router/index.ts frontend/src/views/admin/AdminDashboard.vue frontend/src/api/local/handlers/admin.ts frontend/src/api/local/handlers/products.ts frontend/src/api/local/proxy.ts && git commit -m "feat: add barcode service admin"`

### Task 6: Web barcode input and product maintenance

**Files:**
- Modify: `frontend/package.json`, `frontend/package-lock.json`
- Create: `frontend/src/components/common/BarcodeScannerDialog.vue`
- Create: `frontend/src/components/common/BarcodeField.vue`
- Create: `frontend/src/utils/barcodeLookup.ts`
- Modify: `frontend/src/views/data/ProductsView.vue`
- Modify: `frontend/src/views/products/ProductDetail.vue`
- Modify: `frontend/src/views/ingredients/IngredientDetail.vue`

- [ ] **Step 1: Install scanner dependency**

Run in `frontend`: `npm install @zxing/browser`

Request network escalation if the sandbox blocks npm.

- [ ] **Step 2: Implement reusable camera input**

- `BarcodeScannerDialog` opens camera via `BrowserMultiFormatReader.decodeFromVideoDevice`, accepts common 1D formats, stops reader/camera tracks on close or detected code, and emits one code.
- `BarcodeField` wraps a Vuetify text field plus a camera icon button. It emits `barcode` for scan and Enter/manual commit; it delegates result handling to its parent so forms decide which empty fields to fill.
- `lookupBarcode(barcode)` normalizes backend success and 404 miss into `{found, source, product, errors}`.

- [ ] **Step 3: Wire product forms**

- Add `BarcodeField` beside existing barcode fields in ProductsView add dialog, ProductDetail basic edit, and IngredientDetail product form.
- On lookup, set barcode; fill only empty name, brand, and image fields where the corresponding form already has a field. Do not overwrite user text.
- ProductsView reads query parameters `barcode`, `name`, `brand`, and `returnTo` on mount, opens its add dialog prefilled, returns after save, and writes the created product to `sessionStorage['barcode-price-return']` when returning to a price flow.

- [ ] **Step 4: Verify and commit**

Run: `npm run build`

Commit: `git add frontend/package.json frontend/package-lock.json frontend/src/components/common/BarcodeScannerDialog.vue frontend/src/components/common/BarcodeField.vue frontend/src/utils/barcodeLookup.ts frontend/src/views/data/ProductsView.vue frontend/src/views/products/ProductDetail.vue frontend/src/views/ingredients/IngredientDetail.vue && git commit -m "feat: add web barcode input"`

### Task 7: Web price record flow

**Files:**
- Modify: `frontend/src/views/prices/QuickFillView.vue`

- [ ] **Step 1: Add scan entry**

Put a camera icon beside the existing paste button. On a successful scan call `lookupBarcode`.

- Local hit: append a new row with `productId`, `productName`, price/quantity/unit unchanged from new-row defaults and focus price input.
- External hit but no local product: show a modal with returned name/brand/spec/manufacturer and buttons “新增商品”/“取消”. Confirm stores `{name, brand, barcode}` in `sessionStorage['barcode-new-product']`, then navigates to `/data/products?returnTo=/prices/quick-fill`.
- Miss: show the same confirm modal with barcode only; cancel leaves the quick-fill draft untouched.

- [ ] **Step 2: Restore after product save**

On mount and merchant load, consume `barcode-price-return` from sessionStorage, append a selected new row for that saved product, remove the key, and preserve merchant/date/price drafts.

- [ ] **Step 3: Verify and commit**

Run: `npm run build`

Commit: `git add frontend/src/views/prices/QuickFillView.vue && git commit -m "feat: scan products into price records"`

### Task 8: Merge master and implement mobile

**Files:**
- Modify: `mobile/pubspec.yaml`, `mobile/pubspec.lock`
- Create: `mobile/lib/shared/widgets/barcode_scanner_sheet.dart`
- Create: `mobile/lib/features/products/models/barcode_lookup.dart`
- Modify: `mobile/lib/features/products/repositories/product_repository.dart`
- Modify: `mobile/lib/features/products/screens/product_form_screen.dart`
- Modify: `mobile/lib/features/prices/screens/price_record_form_screen.dart`
- Modify: `mobile/lib/core/router/app_router.dart`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/ios/Runner/Info.plist`
- Test: `mobile/test/features/products/models/barcode_lookup_test.dart`
- Test: `mobile/test/features/products/repositories/product_repository_test.dart`

- [ ] **Step 1: Merge master first**

From `D:\code\live_calc` on `feat/mobile-app`, run `git merge master`. Resolve only conflicts from this feature; do not alter unrelated mobile changes.

- [ ] **Step 2: Write failing model/repository tests**

Model assertions parse local and external payloads and preserve missing fields. Repository test uses mocktail `Dio` and asserts GET `/products/entity/barcode/{barcode}` returns `BarcodeLookupResult`.

- [ ] **Step 3: Verify RED**

Run: `flutter test test/features/products/models/barcode_lookup_test.dart test/features/products/repositories/product_repository_test.dart`

Expected: missing classes/methods fail to compile.

- [ ] **Step 4: Implement mobile scan flow**

- Add `mobile_scanner`.
- Scanner sheet pops once on `BarcodeCapture.rawValue`; expose it as a reusable future helper so widget tests do not instantiate camera platform views.
- Product form adds a camera suffix icon to barcode field, scans, fills empty name/brand, and looks up through repository.
- Add `ProductFormPrefill(barcode, name, brand)` and `ProductFormResult.product`; creation returns the created product.
- Price form adds a camera suffix icon to product field. Local result selects the product. External result opens an add-product dialog; confirm pushes `/products/new` with prefill while preserving entered price/quantity/unit/merchant. After save, select returned product and remain on price form. Miss offers barcode-only creation; cancel changes nothing.
- Add Android camera permission and iOS `NSCameraUsageDescription`.

- [ ] **Step 5: Verify and commit**

Run:

```powershell
flutter test test/features/products/models/barcode_lookup_test.dart test/features/products/repositories/product_repository_test.dart test/features/products/screens/product_form_screen_test.dart test/features/prices/screens/price_record_form_screen_test.dart
flutter analyze
```

Commit mobile changes: `git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib mobile/test mobile/android/app/src/main/AndroidManifest.xml mobile/ios/Runner/Info.plist && git commit -m "feat: add mobile barcode input"`

### Task 9: Final verification and branch state

- [ ] Run focused backend suite from `backend`.
- [ ] Run `uv run python -m py_compile` on every changed Python file.
- [ ] Run `npm run build` from `frontend`.
- [ ] Run full `flutter test` from `mobile`.
- [ ] Run `flutter analyze` from `mobile`.
- [ ] Run `git diff --check`.
- [ ] Confirm master contains Tasks 1-7 and `feat/mobile-app` contains the merge plus Tasks 8-9.
- [ ] Report real-device camera testing as the remaining manual verification; automated environments cannot validate physical focus/lighting.

## Self-Review

- Covers all three built-in providers, multiple custom APIs, priority order, links, secrets, TTL cache, web/mobile camera input, product maintenance autofill, and price-record add-product fallback.
- Avoids third-party credentials in clients; only backend performs provider calls.
- Uses the smallest existing persistence surface (`system_config`) and does not add product columns.
- The cache is deliberately invalidated wholesale on configuration save; per-provider invalidation can be added if provider payloads become frequently reused across configurations.
