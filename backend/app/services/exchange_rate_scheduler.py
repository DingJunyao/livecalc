"""汇率每日拉取调度。"""
from apscheduler.schedulers.background import BackgroundScheduler
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
    _scheduler.start()


def stop_scheduler():
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
