from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.main import init_default_data
from app.models.unit import Unit
from app.services.unit_conversion_service import UnitConversionService
from app.services.unit_matcher import UnitMatcher


@pytest.fixture
def db_session():
    engine = create_engine('sqlite:///:memory:')
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_existing_database_gets_hundred_gram_unit_and_conversion(db_session):
    db_session.add(Unit(name='千克', abbreviation='kg', unit_type='mass', si_factor=1))
    db_session.commit()

    init_default_data(db_session)
    init_default_data(db_session)

    units = db_session.query(Unit).filter(Unit.abbreviation == '100g').all()
    assert len(units) == 1
    unit = units[0]
    assert unit.name == '100克'
    assert unit.unit_type == 'mass'
    assert unit.unit_system == 'metric'
    assert unit.is_common is True
    assert unit.si_factor == Decimal('0.1')

    service = UnitConversionService(db_session)
    converted = service.convert_si(Decimal('2'), unit, db_session.query(Unit).filter_by(abbreviation='kg').one())
    assert converted == Decimal('0.2')


def test_hundred_gram_unit_matches_spacing_variant(db_session):
    init_default_data(db_session)

    matcher = UnitMatcher(db_session)
    unit, created = matcher.match_unit('100 g')

    assert created is False
    assert unit.abbreviation == '100g'
    assert unit.unit_type == 'mass'
