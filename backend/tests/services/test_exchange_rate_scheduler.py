"""汇率调度测试：验证启动即拉取 + 每日 cron。"""
import app.services.exchange_rate_scheduler as mod


class _FakeScheduler:
    def __init__(self):
        self.jobs = []

    def add_job(self, func, trigger, **kwargs):
        self.jobs.append((func, trigger, kwargs))

    def start(self):
        pass

    def shutdown(self, wait=False):
        pass


def _patch(monkeypatch, fetch_on_startup):
    fake = _FakeScheduler()
    monkeypatch.setattr(mod, "BackgroundScheduler", lambda: fake)
    monkeypatch.setattr(
        mod,
        "settings",
        type("S", (), {"exchange_rate_fetch_on_startup": fetch_on_startup})(),
    )
    prev = mod._scheduler
    monkeypatch.setattr(mod, "_scheduler", None)
    return fake, prev


def test_start_scheduler_schedules_startup_fetch_and_daily_cron(monkeypatch):
    fake, prev = _patch(monkeypatch, True)
    try:
        mod.start_scheduler()
        triggers = [trigger for _, trigger, _ in fake.jobs]
        assert "cron" in triggers
        assert "date" in triggers
    finally:
        mod.stop_scheduler()
        monkeypatch.setattr(mod, "_scheduler", prev)


def test_start_scheduler_skips_startup_fetch_when_disabled(monkeypatch):
    fake, prev = _patch(monkeypatch, False)
    try:
        mod.start_scheduler()
        triggers = [trigger for _, trigger, _ in fake.jobs]
        assert triggers == ["cron"]
    finally:
        mod.stop_scheduler()
        monkeypatch.setattr(mod, "_scheduler", prev)
