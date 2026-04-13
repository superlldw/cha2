import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.models.enums import DamType

SEED_PATH = Path(__file__).resolve().parents[2] / "seeds" / "inspection_template_items.json"


@lru_cache(maxsize=1)
def load_template_seed() -> list[dict[str, Any]]:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    return payload["items"]


def _is_chapter_enabled(chapter_code: str, enabled_chapters: list[str]) -> bool:
    return chapter_code in enabled_chapters


def _normalize_dam_type(dam_type: DamType | str) -> DamType:
    if isinstance(dam_type, DamType):
        return dam_type
    return DamType(dam_type)


def _dam_type_filter(chapter_code: str, dam_type: DamType | str) -> bool:
    dam_type = _normalize_dam_type(dam_type)
    if dam_type in {DamType.earthfill, DamType.rockfill}:
        return chapter_code != "A3"
    if dam_type in {DamType.concrete, DamType.masonry}:
        return chapter_code != "A2"
    return True


def _build_tree(filtered_items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_code = {item["item_code"]: item for item in filtered_items}
    chapters = sorted(
        [i for i in filtered_items if i["item_type"] == "chapter"],
        key=lambda x: x["sort_order"],
    )
    sections = sorted(
        [i for i in filtered_items if i["item_type"] == "section"],
        key=lambda x: x["sort_order"],
    )
    leaves = sorted(
        [i for i in filtered_items if i["item_type"] == "inspection_item"],
        key=lambda x: x["sort_order"],
    )

    leaves_by_parent: dict[str, list[dict[str, Any]]] = {}
    for leaf in leaves:
        leaves_by_parent.setdefault(leaf["parent_code"], []).append(leaf)

    sections_by_chapter: dict[str, list[dict[str, Any]]] = {}
    for section in sections:
        sections_by_chapter.setdefault(section["chapter_code"], []).append(section)

    tree: list[dict[str, Any]] = []
    for chapter in chapters:
        chapter_node = {
            "chapter_code": chapter["item_code"],
            "chapter_name": chapter["item_name"],
            "children": [],
        }
        for section in sections_by_chapter.get(chapter["item_code"], []):
            section_node = {
                "item_code": section["item_code"],
                "item_name": section["item_name"],
                "item_type": section["item_type"],
                "children": [],
            }
            for leaf in leaves_by_parent.get(section["item_code"], []):
                if leaf["parent_code"] not in by_code:
                    continue
                section_node["children"].append(
                    {
                        "item_code": leaf["item_code"],
                        "item_name": leaf["item_name"],
                        "item_type": leaf["item_type"],
                        "supports_photo": leaf["supports_photo"],
                        "supports_audio": leaf["supports_audio"],
                        "supports_location": leaf["supports_location"],
                        "supports_attachment": leaf["supports_attachment"],
                    }
                )
            chapter_node["children"].append(section_node)
        tree.append(chapter_node)
    return tree


def get_task_template_tree(dam_type: DamType | str, enabled_chapters: list[str]) -> list[dict[str, Any]]:
    dam_type = _normalize_dam_type(dam_type)
    items = load_template_seed()
    filtered = [
        item
        for item in items
        if _is_chapter_enabled(item["chapter_code"], enabled_chapters)
        and _dam_type_filter(item["chapter_code"], dam_type)
        and dam_type.value in item["applicable_dam_type"]
    ]
    return _build_tree(filtered)


def get_template_item(item_code: str) -> dict[str, Any] | None:
    for item in load_template_seed():
        if item["item_code"] == item_code:
            return item
    return None


def get_enabled_inspection_items(dam_type: DamType | str, enabled_chapters: list[str]) -> list[dict[str, Any]]:
    dam_type = _normalize_dam_type(dam_type)
    items = load_template_seed()
    return [
        item
        for item in items
        if item["item_type"] == "inspection_item"
        and _is_chapter_enabled(item["chapter_code"], enabled_chapters)
        and _dam_type_filter(item["chapter_code"], dam_type)
        and dam_type.value in item["applicable_dam_type"]
    ]
