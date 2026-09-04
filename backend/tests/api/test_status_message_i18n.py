from fastapi import Request

from app.core.i18n import api_message


def _request(locale: str) -> Request:
    return Request(
        scope={
            "type": "http",
            "headers": [(b"accept-language", locale.encode("ascii"))],
            "state": {},
        }
    )


def test_api_message_uses_request_locale_and_interpolation():
    assert api_message(_request("en-US"), "Preference deleted successfully") == "Preference deleted successfully"
    assert api_message(_request("ar"), "Preference deleted successfully") == "تم حذف التفضيل بنجاح"
    assert api_message(
        _request("en-US"),
        "删除提议已提交（proposal_id={proposal_id}, status={status}）",
        proposal_id=12,
        status="pending",
    ) == "Deletion proposal submitted (proposal_id=12, status=pending)"

    assert api_message(_request("en-US"), "Product not found") == "Product not found"
    assert api_message(_request("ar"), "Product not found") == "لم يتم العثور على المنتج"
