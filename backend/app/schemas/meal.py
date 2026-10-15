"""
每日饮食推荐 - 请求/响应 Schema

多道菜套餐（设计 §4.7）：recommendations[].dishes 为完整套餐；
recipe 保留为兼容别名（staple 或首道菜），旧前端可继续消费。
"""
from pydantic import BaseModel, Field
from typing import Optional, List


class NutritionGoals(BaseModel):
    """营养目标"""
    daily_calorie_target: Optional[float] = 2000
    daily_protein_target: Optional[float] = 60
    daily_carb_target: Optional[float] = 300
    daily_fat_target: Optional[float] = 65
    daily_budget: Optional[float] = None


class RecipeBrief(BaseModel):
    """推荐中的菜谱简要信息"""
    id: int
    name: str
    category: Optional[str] = None
    images: Optional[List[str]] = None
    image_urls: Optional[List[str]] = None  # 已解析的完整 URL（S3 直连 / local 路径）
    servings: int = 1
    cost_estimate: Optional[float] = None
    currency: Optional[str] = None
    nutrition_per_serving: Optional[dict] = None

    class Config:
        from_attributes = True


class RecommendedDish(RecipeBrief):
    """套餐中的一道菜"""
    role: str = "main"  # staple | main | side | soup | drink
    reason: Optional[str] = None


class MealRecommendationItem(BaseModel):
    """单餐推荐（多道菜套餐）"""
    meal_type: str
    recipe: Optional[RecipeBrief] = None  # 兼容别名：staple（无则首道）菜
    dishes: List[RecommendedDish] = []
    source: Optional[str] = None  # rule | system_ai | user_ai | plan
    reason: Optional[str] = None
    preference: Optional[str] = None
    plan: Optional[dict] = None  # source='plan' 时的方案视图
    is_current_meal: bool = False


class DailyTotals(BaseModel):
    """当日汇总"""
    cost: Optional[float] = None
    currency: Optional[str] = None
    calories: Optional[float] = None
    protein_g: Optional[float] = None
    carbs_g: Optional[float] = None
    fat_g: Optional[float] = None
    refresh_counts: Optional[dict] = None


class MealRecommendationsResponse(BaseModel):
    """完整推荐响应

    status 取值：
    - "ready": 推荐已就绪，直接展示
    - "not_generated": 尚未生成，需调用 POST /generate 触发后台计算
    - "generating": 后台正在生成中，前端应轮询 GET 直到 ready

    refreshing_meals: 当前正在后台刷新的餐类列表，仅在 status="ready" 时有意义。
    """
    status: str = "ready"
    date: str
    recommendations: List[MealRecommendationItem] = []
    totals: Optional[DailyTotals] = None
    refreshing_meals: List[str] = []


class GenerateMealRequest(BaseModel):
    """生成今日推荐的可选参数"""
    preference: Optional[str] = Field(None, max_length=200, description="一句话偏好")


class RefreshMealRequest(BaseModel):
    """刷新某一餐请求

    recipe_id 为空 = 整餐重搭；给定 = 单道换（只替换该道菜）。
    """
    meal_type: str = Field(..., pattern="^(breakfast|lunch|dinner)$")
    recipe_id: Optional[int] = None
    preference: Optional[str] = Field(None, max_length=200, description="一句话偏好")
