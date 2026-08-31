"""应用自定义异常类层次结构。

提供统一的业务异常类型，配合全局异常处理器使用，
确保 API 返回结构化的错误响应。
"""

from typing import Any

from starlette.exceptions import HTTPException as StarletteHTTPException


class AppException(Exception):
    """应用基础异常，所有自定义异常均继承此类。"""

    def __init__(self, detail: str, status_code: int = 500, params: dict[str, Any] | None = None):
        self.detail = detail
        self.status_code = status_code
        self.params = params or {}
        super().__init__(detail)


class LocalizedAppException(AppException):
    """携带中文 msgid 与插值参数的本地化应用异常。"""

    def __init__(self, status_code: int, message: str, **params: Any):
        super().__init__(detail=message, status_code=status_code, params=params)
        self.message = message


class LocalizedHTTPException(StarletteHTTPException):
    """携带中文 msgid 与插值参数的本地化 HTTP 异常。"""

    def __init__(self, status_code: int, message: str, **params: Any):
        super().__init__(status_code=status_code, detail=message)
        self.message = message
        self.params = params


class NotFoundException(AppException):
    """资源未找到异常 (404)。"""

    def __init__(self, detail: str = "请求的资源不存在"):
        super().__init__(detail=detail, status_code=404)


class BadRequestException(AppException):
    """请求参数错误异常 (400)。"""

    def __init__(self, detail: str = "请求参数有误"):
        super().__init__(detail=detail, status_code=400)


class ConflictException(AppException):
    """资源冲突异常 (409)。"""

    def __init__(self, detail: str = "资源已存在，无法重复创建"):
        super().__init__(detail=detail, status_code=409)


class ForbiddenException(AppException):
    """权限不足异常 (403)。"""

    def __init__(self, detail: str = "没有权限执行此操作"):
        super().__init__(detail=detail, status_code=403)


class UnauthorizedException(AppException):
    """未认证异常 (401)。"""

    def __init__(self, detail: str = "请先登录"):
        super().__init__(detail=detail, status_code=401)


class DatabaseException(AppException):
    """数据库操作异常 (500)。"""

    def __init__(self, detail: str = "数据库操作失败，请稍后重试"):
        super().__init__(detail=detail, status_code=500)
