import asyncio
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import Request

from app.api import ingredient_hierarchy, nutrition
from app.api.ingredient_hierarchy import (
    IngredientMergeRequest,
    IngredientMergeResponse,
)
from app.core.i18n import api_message
from app.schemas.ingredient_merge import (
    IngredientMergeResponse as SharedIngredientMergeResponse,
)
from app.schemas.nutrition import NutritionEditRequest, NutritionEditResponse


def _request(locale: str = "en-US") -> Request:
    return Request(
        scope={
            "type": "http",
            "headers": [(b"accept-language", locale.encode("ascii"))],
            "state": {},
        }
    )


def _pending_proposal():
    return SimpleNamespace(id=77, status="pending")


def _nutrition_db(entity):
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = entity
    return db


def _merge_db():
    db = MagicMock()
    query = db.query.return_value
    query.filter.return_value.all.return_value = [SimpleNamespace(name="source")]
    query.get.return_value = SimpleNamespace(name="target")
    query.filter.return_value.count.return_value = 0
    return db


def test_edit_ingredient_nutrition_pending_exposes_fields_and_translates():
    db = _nutrition_db(SimpleNamespace(id=41, custom_nutrition_data={}))
    with patch.object(
        nutrition.proposal_service, "submit", return_value=_pending_proposal()
    ):
        response = asyncio.run(
            nutrition.edit_ingredient_nutrition(
                ingredient_id=41,
                http_request=_request("en-US"),
                request=NutritionEditRequest(nutrients=[]),
                db=db,
                current_user=SimpleNamespace(is_admin=False, id=2),
            )
        )

    assert response.status == "pending"
    assert response.proposal_id == 77
    assert response.message == "Nutrition update proposal submitted (status=pending, pending admin review)"


def test_edit_product_nutrition_pending_exposes_fields_and_translates():
    db = _nutrition_db(SimpleNamespace(id=42, custom_nutrition_data={}))
    with patch.object(
        nutrition.proposal_service, "submit", return_value=_pending_proposal()
    ):
        response = asyncio.run(
            nutrition.edit_product_nutrition(
                product_id=42,
                http_request=_request("ar"),
                request=NutritionEditRequest(nutrients=[]),
                db=db,
                current_user=SimpleNamespace(is_admin=False, id=2),
            )
        )

    assert response.status == "pending"
    assert response.proposal_id == 77
    assert response.message == "تم إرسال اقتراح تحديث التغذية (status=pending، بانتظار مراجعة المسؤول)"


def test_merge_ingredients_pending_exposes_fields_and_translates():
    db = _merge_db()
    with patch.object(
        ingredient_hierarchy.proposal_service,
        "submit",
        return_value=_pending_proposal(),
    ):
        response = ingredient_hierarchy.merge_ingredients(
            merge_request=IngredientMergeRequest(
                source_ingredient_ids=[1],
                target_ingredient_id=2,
            ),
            request=_request("en-US"),
            current_user=SimpleNamespace(is_admin=False, id=2),
            db=db,
        )

    assert response.status == "pending"
    assert response.proposal_id == 77
    assert response.message == "Merge proposal submitted (proposal_id=77, status=pending)"


def test_pending_schema_fields_are_optional_and_serializable():
    nutrition_response = NutritionEditResponse(
        success=True,
        message="ok",
        status="pending",
        proposal_id=77,
    )
    assert nutrition_response.status == "pending"
    assert nutrition_response.proposal_id == 77

    local_merge_response = IngredientMergeResponse(
        success=True,
        message="ok",
        merged_count=1,
        updated_recipes_count=0,
        updated_products_count=0,
        updated_mappings_count=0,
        stats_change={},
        status="pending",
        proposal_id=77,
    )
    assert local_merge_response.status == "pending"
    assert local_merge_response.proposal_id == 77

    shared_merge_response = SharedIngredientMergeResponse(
        success=True,
        message="ok",
        status="pending",
        proposal_id=77,
    )
    assert shared_merge_response.status == "pending"
    assert shared_merge_response.proposal_id == 77


def test_blacklist_ai_match_messages_use_request_locale():
    assert api_message(
        _request("en-US"),
        "已触发全部启用分组 AI 匹配任务，可在 Agent 任务台查看进度",
    ) == "AI matching task started for all enabled groups; view progress on the Agent task board."
    assert api_message(
        _request("ar"),
        "已触发 AI 匹配任务，可在 Agent 任务台查看进度",
    ) == "بدأت مهمة مطابقة AI؛ يمكنك متابعة التقدم في لوحة مهام الوكيل."
