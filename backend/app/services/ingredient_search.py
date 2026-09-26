"""Helpers for ingredient searches."""

import re
import unicodedata
from difflib import SequenceMatcher
from typing import Iterable


def _normalize(value: str) -> str:
    """Normalize names for case-, width-, and whitespace-insensitive matching."""
    value = unicodedata.normalize("NFKC", value or "").casefold()
    return re.sub(r"[\W_]+", "", value, flags=re.UNICODE)


def _is_within_one_edit(left: str, right: str) -> bool:
    """Return whether two equal-ish strings differ by at most one replacement."""
    if abs(len(left) - len(right)) > 1:
        return False

    # Replacements are the common CJK typo case. Insertions/deletions are not
    # accepted here because deleting a suffix already works through substring search.
    if len(left) == len(right):
        return sum(a != b for a, b in zip(left, right)) == 1

    # A one-character insertion/deletion is useful for Latin input, but require a
    # long common block so unrelated short words do not match each other.
    if SequenceMatcher(None, left, right).ratio() < 0.8:
        return False
    return True


def is_close_search_match(query: str, candidates: Iterable[str | None]) -> bool:
    """Whether a query is a one-character typo for any candidate text.

    A direct substring is intentionally not considered here: callers try SQL
    substring matching first and use this helper only as a fallback.
    """
    normalized_query = _normalize(query)
    if len(normalized_query) < 3:
        return False

    # The retained prefix prevents unrelated words with similar letter mixes
    # (for example, tomato/potato) from being treated as typos.
    required_prefix = normalized_query[:2]
    for candidate in candidates:
        normalized_candidate = _normalize(candidate or "")
        if not normalized_candidate:
            continue
        if _is_within_one_edit(normalized_query, normalized_candidate) and (
            required_prefix in normalized_candidate
            or normalized_candidate[:2] in normalized_query
        ):
            return True
    return False


def find_fuzzy_ingredient_ids(db, search: str) -> set[int]:
    """Find active ingredients whose names/aliases/products match a typo query."""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product

    ingredient_rows = db.query(
        Ingredient.id, Ingredient.name, Ingredient.aliases
    ).filter(Ingredient.is_active == True).all()

    product_names: dict[int, list[str]] = {}
    product_rows = db.query(
        Product.ingredient_id, Product.name, Product.aliases
    ).filter(Product.is_active == True, Product.ingredient_id.isnot(None)).all()
    for ingredient_id, name, aliases in product_rows:
        product_names.setdefault(ingredient_id, []).extend(
            [name, *(aliases or [])]
        )

    matched_ids: set[int] = set()
    for ingredient_id, name, aliases in ingredient_rows:
        candidates = [name, *(aliases or []), *product_names.get(ingredient_id, [])]
        if is_close_search_match(search, candidates):
            matched_ids.add(ingredient_id)
    return matched_ids
