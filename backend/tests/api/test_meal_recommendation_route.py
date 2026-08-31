import inspect
from types import SimpleNamespace

import pytest

from app.api.meals import (
    get_daily_recommendations,
    refresh_recommendation,
    trigger_recommendation_generation,
)
from app.core.exceptions import LocalizedHTTPException


def test_recommendation_routes_are_sync_for_threadpool_offload():
    """Heavy recipe scoring must not run directly on the async event loop."""
    assert not inspect.iscoroutinefunction(get_daily_recommendations)
    assert not inspect.iscoroutinefunction(trigger_recommendation_generation)
    assert not inspect.iscoroutinefunction(refresh_recommendation)


def test_refresh_conflict_preserves_service_error(monkeypatch):
    import app.api.meals as meals_module

    from app.services import meal_recommender

    monkeypatch.setattr(meal_recommender, "_count_today_refreshes", lambda *args, **kwargs: {})
    monkeypatch.setattr(meals_module, "is_refreshing", lambda *args, **kwargs: False)
    monkeypatch.setattr(
        meals_module,
        "check_today_status",
        lambda *args, **kwargs: {
            "status": "ready",
            "existing_records": [],
            "refreshing_meals": [],
        },
    )
    monkeypatch.setattr(
        meals_module,
        "trigger_background_refresh",
        lambda *args, **kwargs: (False, "already refreshing"),
    )

    request = SimpleNamespace(meal_type="lunch")
    current_user = SimpleNamespace(id=1)
    with pytest.raises(LocalizedHTTPException) as exc_info:
        refresh_recommendation(request, db=None, current_user=current_user, tz="UTC")

    assert exc_info.value.message == "刷新失败: {error}"
    assert exc_info.value.params["error"] == "already refreshing"
