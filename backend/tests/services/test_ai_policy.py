"""AI 使用策略层单元测试：加密、解析顺序、每日上限、用量留痕。"""
import datetime

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def _today():
    return datetime.datetime.now(datetime.timezone.utc).date()


def test_api_key_encrypt_roundtrip_and_mask():
    from app.services.ai_policy import encrypt_api_key, decrypt_api_key, mask_key

    enc = encrypt_api_key("sk-test-1234567890abcdef")
    assert enc != "sk-test-1234567890abcdef"
    assert decrypt_api_key(enc) == "sk-test-1234567890abcdef"
    masked = mask_key("sk-test-1234567890abcdef")
    assert "1234567890" not in masked and masked != "sk-test-1234567890abcdef"


def test_resolve_method_order_and_allow_flags():
    Base.metadata.create_all(bind=engine)
    from app.models.user_ai_settings import UserAiSettings
    from app.services.ai_policy import get_policy, resolve_ai_credentials
    from app.core.database import SessionLocal

    db = TestingSessionLocal()
    try:
        # 共享内存库：清掉其他用例留下的设置行，保证从干净态开始
        from app.models.user_ai_settings import UserAiSettings as _S
        db.query(_S).delete()
        db.commit()
        # 无用户设置、无全局配置 → 默认 method=system_ai（默认 provider=claude_code，无需 key）
        policy = get_policy(db)
        assert policy["default_method"] in ("rule", "system_ai")
        creds = resolve_ai_credentials(db, FakeUser())
        assert creds["method"] in ("rule", "system_ai")

        # 用户设置 method=rule → 强制规则
        db.add(UserAiSettings(user_id=FakeUser.id, method="rule"))
        db.commit()
        creds = resolve_ai_credentials(db, FakeUser())
        assert creds["method"] == "rule"

        # 用户 method=rule 时即使全局 system_ai 也规则
        db.query(UserAiSettings).delete()
        db.commit()
    finally:
        db.close()


def test_daily_limit_and_usage_events():
    Base.metadata.create_all(bind=engine)
    from app.models.ai_usage_event import AiUsageEvent
    from app.services.ai_policy import (
        count_today_system_ai_usage, record_usage, system_ai_limit_reached,
    )

    db = TestingSessionLocal()
    try:
        from app.models.ai_usage_event import AiUsageEvent as _E

        db.query(_E).filter(_E.user_id == FakeUser.id).delete()
        db.commit()
        assert count_today_system_ai_usage(db, FakeUser.id) == 0
        policy = {"daily_ai_limit": 2}
        assert system_ai_limit_reached(db, FakeUser(), policy) is False

        for _ in range(2):
            record_usage(db, FakeUser.id, "meal_plan", "system_ai", "claude_code", "ok")
        assert count_today_system_ai_usage(db, FakeUser.id) == 2
        assert system_ai_limit_reached(db, FakeUser(), policy) is True

        # fallback 也计入；error 不计入（error 不消耗产出，但可留痕）
        record_usage(db, FakeUser.id, "meal_plan", "system_ai", "claude_code", "error")
        assert count_today_system_ai_usage(db, FakeUser.id) == 2

        # 用户级覆盖优先
        user = FakeUser()
        assert system_ai_limit_reached(db, user, policy) is True
    finally:
        db.close()
