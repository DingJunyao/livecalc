"""检查无商家价格记录、无地区商家、currency 异常。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.product import ProductRecord
from app.models.merchant import Merchant

def main():
    db = SessionLocal()
    no_merchant = db.query(ProductRecord).filter(ProductRecord.merchant_id.is_(None)).count()
    no_region = db.query(Merchant).filter(Merchant.region_id.is_(None)).count()
    bad_currency = db.query(ProductRecord).filter(
        (ProductRecord.currency.is_(None)) | (ProductRecord.currency == "")
    ).count()
    print(f"无商家价格记录: {no_merchant}")
    print(f"无地区商家: {no_region}")
    print(f"currency 为空/异常记录: {bad_currency}")
    db.close()

if __name__ == "__main__":
    main()