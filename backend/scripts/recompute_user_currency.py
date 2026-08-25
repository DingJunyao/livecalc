"""命令行入口：重算所有价格记录到指定用户默认币种。"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.scripts.recompute_user_currency import recompute_all


def main():
    parser = argparse.ArgumentParser(description="重算历史价格记录的用户币种快照")
    parser.add_argument("currency", help="目标用户默认币种，如 CNY")
    args = parser.parse_args()
    db = SessionLocal()
    try:
        print(recompute_all(db, args.currency.upper()))
    finally:
        db.close()


if __name__ == "__main__":
    main()
