"""地理编码 adcode 匹配测试。"""
from app.services.geocoding import match_adcode_to_region_id

def test_match_adcode_function_exists():
    assert callable(match_adcode_to_region_id)
