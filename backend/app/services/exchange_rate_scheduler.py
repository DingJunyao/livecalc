"""汇率每日拉取调度。"""
from datetime import datetime

from apscheduler.schedulers.background import BackgroundScheduler
from app.config import settings
from app.core.database import get_db
from app.services import exchange_rate_service

_scheduler: BackgroundScheduler | None = None


def _job():
    db = next(get_db())
    try:
        exchange_rate_service.fetch_and_store_daily(db)
    except Exception:
        pass
    finally:
        db.close()


def start_scheduler():
    global _scheduler
    if _scheduler is not None:
        return
    _scheduler = BackgroundScheduler()
    _scheduler.add_job(_job, "cron", hour=3, minute=0, id="exchange-rate-daily")
    if settings.exchange_rate_fetch_on_startup:
        # 启动即拉取一次：新部署/重启后立即可用，不依赖凌晨 3 点 cron；
        # 后台线程执行，失败不阻断启动（_job 内部已吞异常）。
        _scheduler.add_job(_job, "date", run_date=datetime.now(), id="exchange-rate-startup")
    _scheduler.start()


def stop_scheduler():
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
