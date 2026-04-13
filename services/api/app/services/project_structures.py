from collections.abc import Iterable

from app.models.enums import StructureCategory, StructureObjectType

OBJECT_TYPE_META: dict[StructureObjectType, dict[str, str | bool]] = {
    StructureObjectType.main_dam: {
        "label": "主坝",
        "category": StructureCategory.water_retaining.value,
        "template": StructureObjectType.main_dam.value,
        "single": "true",
    },
    StructureObjectType.aux_dam: {
        "label": "副坝",
        "category": StructureCategory.water_retaining.value,
        "template": StructureObjectType.aux_dam.value,
        "single": "false",
    },
    StructureObjectType.spillway: {
        "label": "溢洪道",
        "category": StructureCategory.water_releasing.value,
        "template": StructureObjectType.spillway.value,
        "single": "true",
    },
    StructureObjectType.outlet_tunnel: {
        "label": "输水洞",
        "category": StructureCategory.water_conveyance.value,
        "template": StructureObjectType.outlet_tunnel.value,
        "single": "false",
    },
    StructureObjectType.spill_tunnel: {
        "label": "泄洪洞",
        "category": StructureCategory.water_releasing.value,
        "template": StructureObjectType.spill_tunnel.value,
        "single": "false",
    },
    StructureObjectType.power_tunnel: {
        "label": "发电洞",
        "category": StructureCategory.power_generation.value,
        "template": StructureObjectType.power_tunnel.value,
        "single": "false",
    },
    StructureObjectType.admin_facility: {
        "label": "管理设施",
        "category": StructureCategory.management.value,
        "template": StructureObjectType.admin_facility.value,
        "single": "false",
    },
    StructureObjectType.updownstream_env: {
        "label": "上下游环境对象",
        "category": StructureCategory.environment.value,
        "template": StructureObjectType.updownstream_env.value,
        "single": "false",
    },
    StructureObjectType.custom: {
        "label": "自定义对象",
        "category": StructureCategory.other.value,
        "template": StructureObjectType.main_dam.value,
        "single": "false",
    },
}

STRUCTURE_PART_TEMPLATES: dict[StructureObjectType, list[dict[str, str | int]]] = {
    StructureObjectType.main_dam: [
        {"part_code": "dam_crest", "part_name": "坝顶", "sort_order": 10},
        {"part_code": "upstream_face", "part_name": "上游面", "sort_order": 20},
        {"part_code": "downstream_face", "part_name": "下游面", "sort_order": 30},
        {"part_code": "dam_abutment", "part_name": "坝肩", "sort_order": 40},
        {"part_code": "dam_foundation", "part_name": "坝基附近", "sort_order": 50},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.aux_dam: [
        {"part_code": "dam_crest", "part_name": "坝顶", "sort_order": 10},
        {"part_code": "upstream_face", "part_name": "上游面", "sort_order": 20},
        {"part_code": "downstream_face", "part_name": "下游面", "sort_order": 30},
        {"part_code": "dam_abutment", "part_name": "坝肩", "sort_order": 40},
        {"part_code": "dam_foundation", "part_name": "坝基附近", "sort_order": 50},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.spillway: [
        {"part_code": "inlet", "part_name": "进口段", "sort_order": 10},
        {"part_code": "control", "part_name": "控制段", "sort_order": 20},
        {"part_code": "chute", "part_name": "泄槽段", "sort_order": 30},
        {"part_code": "energy_dissipation", "part_name": "消能段", "sort_order": 40},
        {"part_code": "tailwater", "part_name": "尾水段", "sort_order": 50},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.outlet_tunnel: [
        {"part_code": "inlet", "part_name": "进口段", "sort_order": 10},
        {"part_code": "tunnel_body", "part_name": "洞身段", "sort_order": 20},
        {"part_code": "outlet", "part_name": "出口段", "sort_order": 30},
        {"part_code": "hoist", "part_name": "启闭设施", "sort_order": 40},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.spill_tunnel: [
        {"part_code": "inlet", "part_name": "进口段", "sort_order": 10},
        {"part_code": "tunnel_body", "part_name": "洞身段", "sort_order": 20},
        {"part_code": "outlet", "part_name": "出口段", "sort_order": 30},
        {"part_code": "hoist", "part_name": "启闭设施", "sort_order": 40},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.power_tunnel: [
        {"part_code": "inlet", "part_name": "进口段", "sort_order": 10},
        {"part_code": "tunnel_body", "part_name": "洞身段", "sort_order": 20},
        {"part_code": "outlet", "part_name": "出口段", "sort_order": 30},
        {"part_code": "hoist", "part_name": "启闭设施", "sort_order": 40},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.admin_facility: [
        {"part_code": "main_building", "part_name": "主体建筑", "sort_order": 10},
        {"part_code": "equipment", "part_name": "设备设施", "sort_order": 20},
        {"part_code": "power_lighting", "part_name": "电源照明", "sort_order": 30},
        {"part_code": "communication_monitor", "part_name": "通信监测", "sort_order": 40},
        {"part_code": "surrounding_road", "part_name": "周边道路", "sort_order": 50},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
    StructureObjectType.updownstream_env: [
        {"part_code": "bank", "part_name": "库岸", "sort_order": 10},
        {"part_code": "river_channel", "part_name": "河道", "sort_order": 20},
        {"part_code": "slope", "part_name": "岸坡", "sort_order": 30},
        {"part_code": "bridge_path", "part_name": "桥梁/通道", "sort_order": 40},
        {"part_code": "hazard_zone", "part_name": "障碍物/隐患区", "sort_order": 50},
        {"part_code": "other", "part_name": "其他", "sort_order": 90},
    ],
}


def get_object_meta(object_type: StructureObjectType) -> dict[str, str | bool]:
    return OBJECT_TYPE_META[object_type]


def build_default_instance_names(object_type: StructureObjectType, count: int) -> list[str]:
    meta = get_object_meta(object_type)
    label = str(meta["label"])
    if str(meta["single"]).lower() == "true":
        return [label]
    if count <= 1:
        return [f"{label}1"]
    return [f"{label}{idx}" for idx in range(1, count + 1)]


def list_structure_part_templates(object_type: StructureObjectType | None = None) -> list[dict[str, str | int]]:
    output: list[dict[str, str | int]] = []
    object_types: Iterable[StructureObjectType]
    if object_type is None:
        object_types = [
            StructureObjectType.main_dam,
            StructureObjectType.aux_dam,
            StructureObjectType.spillway,
            StructureObjectType.outlet_tunnel,
            StructureObjectType.spill_tunnel,
            StructureObjectType.power_tunnel,
            StructureObjectType.admin_facility,
            StructureObjectType.updownstream_env,
        ]
    else:
        object_types = [object_type]

    for obj_type in object_types:
        for part in STRUCTURE_PART_TEMPLATES.get(obj_type, []):
            output.append(
                {
                    "template_code": obj_type.value,
                    "object_type": obj_type.value,
                    "part_code": str(part["part_code"]),
                    "part_name": str(part["part_name"]),
                    "sort_order": int(part["sort_order"]),
                }
            )
    return output


def get_part_name(object_type: StructureObjectType | str, part_code: str) -> str | None:
    resolved = StructureObjectType(object_type) if isinstance(object_type, str) else object_type
    for part in STRUCTURE_PART_TEMPLATES.get(resolved, []):
        if part["part_code"] == part_code:
            return str(part["part_name"])
    return None