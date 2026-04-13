from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


ALL_DAM_TYPES = ["earthfill", "rockfill", "concrete", "masonry"]

CHAPTERS = {
    "A1": "现场安全检查基本情况",
    "A2": "挡水建筑物现场检查情况——土石坝",
    "A3": "挡水建筑物现场检查情况——混凝土坝与浆砌石坝",
    "A4": "泄水建筑物现场检查情况——溢洪道",
    "A5": "泄水建筑物现场检查情况——溢（泄）洪隧洞",
    "A6": "输（引）水建筑物现场检查情况",
    "A7": "管理设施现场检查情况",
    "A8": "水库上下游现场检查情况",
}

CHAPTER_DAM_TYPES = {
    "A1": ALL_DAM_TYPES,
    "A2": ["earthfill", "rockfill"],
    "A3": ["concrete", "masonry"],
    "A4": ALL_DAM_TYPES,
    "A5": ALL_DAM_TYPES,
    "A6": ALL_DAM_TYPES,
    "A7": ALL_DAM_TYPES,
    "A8": ALL_DAM_TYPES,
}


@dataclass(frozen=True)
class SectionDef:
    code: str
    name: str
    leaf_codes: list[str]


TEMPLATE_STRUCTURE: dict[str, list[SectionDef]] = {
    "A1": [
        SectionDef(
            code="A1_BASIC",
            name="基本情况",
            leaf_codes=[
                "A1_BASIC_RES_NAME",
                "A1_BASIC_DESC",
                "A1_HUB_MAIN_STRUCTURES",
                "A1_FLOOD_PROTECT_OBJ",
                "A1_CHECK_TIME",
                "A1_WEATHER",
                "A1_WATER_LEVEL",
                "A1_STORAGE",
                "A1_INSPECTORS",
                "A1_MAIN_PROBLEM_DESC",
            ],
        )
    ],
    "A2": [
        SectionDef("A2_CREST", "坝顶", ["A2_CREST_ROAD", "A2_CREST_DRAIN", "A2_CREST_WAVE_WALL"]),
        SectionDef(
            "A2_BODY",
            "坝体",
            [
                "A2_BODY_FILL",
                "A2_BODY_APPEARANCE",
                "A2_BODY_UP_PROTECT",
                "A2_BODY_UP_CUSHION",
                "A2_BODY_UP_FILTER",
                "A2_BODY_UP_DRAIN",
                "A2_BODY_DOWN_PROTECT",
                "A2_BODY_DOWN_CUSHION",
                "A2_BODY_DOWN_FILTER",
                "A2_BODY_DOWN_DRAIN",
            ],
        ),
        SectionDef("A2_FOUND", "坝基", ["A2_FOUND_UP", "A2_FOUND_DOWN", "A2_FOUND_CUTOFF"]),
        SectionDef("A2_ABUT", "坝肩", ["A2_ABUT_LEFT", "A2_ABUT_RIGHT"]),
        SectionDef("A2_DOWN_GROUND", "下游地面", ["A2_DOWN_GROUND_DITCH", "A2_DOWN_GROUND_CHANNEL"]),
        SectionDef("A2_NEARBANK", "近坝库岸", ["A2_NEARBANK_LEFT", "A2_NEARBANK_RIGHT"]),
        SectionDef("A2_OTHER_SECTION", "其他", ["A2_OTHER"]),
    ],
    "A3": [
        SectionDef("A3_CREST", "坝顶", ["A3_CREST_ROAD", "A3_CREST_DRAIN"]),
        SectionDef(
            "A3_BODY",
            "坝体",
            [
                "A3_BODY_CONCRETE",
                "A3_BODY_APPEARANCE",
                "A3_BODY_UP_FACE",
                "A3_BODY_DOWN_FACE",
                "A3_BODY_DRAIN",
                "A3_BODY_GALLERY",
            ],
        ),
        SectionDef("A3_FOUND", "坝基", ["A3_FOUND_UP", "A3_FOUND_DOWN", "A3_FOUND_CURTAIN", "A3_FOUND_DRAIN"]),
        SectionDef("A3_ABUT", "坝肩", ["A3_ABUT_LEFT", "A3_ABUT_RIGHT"]),
        SectionDef("A3_DOWN_GROUND", "下游地面", ["A3_DOWN_GROUND_DITCH", "A3_DOWN_GROUND_CHANNEL"]),
        SectionDef("A3_NEARBANK", "近坝库岸", ["A3_NEARBANK_LEFT", "A3_NEARBANK_RIGHT"]),
        SectionDef("A3_OTHER_SECTION", "其他", ["A3_OTHER"]),
    ],
    "A4": [
        SectionDef("A4_INLET", "进口段", ["A4_INLET_LEFT_WALL", "A4_INLET_RIGHT_WALL", "A4_INLET_FLOOR"]),
        SectionDef(
            "A4_CTRL",
            "控制段",
            [
                "A4_CTRL_LEFT_WALL",
                "A4_CTRL_RIGHT_WALL",
                "A4_CTRL_PIER",
                "A4_CTRL_CORBEL",
                "A4_CTRL_FLOOR",
                "A4_CTRL_WEIR",
                "A4_CTRL_TRASH_RACK",
            ],
        ),
        SectionDef(
            "A4_GATE",
            "闸门系统",
            ["A4_GATE_MAINT", "A4_GATE_MAINT_SLOT", "A4_GATE_WORK", "A4_GATE_WORK_SLOT", "A4_GATE_VENT"],
        ),
        SectionDef(
            "A4_HOIST",
            "启闭系统",
            ["A4_HOIST_HOUSE", "A4_HOIST_MACHINE", "A4_HOIST_CONTROL", "A4_HOIST_POWER", "A4_BACKUP_POWER"],
        ),
        SectionDef("A4_CHUTE", "泄槽", ["A4_CHUTE_LEFT_WALL", "A4_CHUTE_RIGHT_WALL", "A4_CHUTE_FLOOR"]),
        SectionDef(
            "A4_ENERGY",
            "消能段",
            ["A4_ENERGY_BUCKET", "A4_ENERGY_BASIN", "A4_ENERGY_FLOOR", "A4_ENERGY_DROP"],
        ),
        SectionDef("A4_TAIL", "尾水", ["A4_TAIL_CHANNEL", "A4_TAIL_RIVER"]),
        SectionDef("A4_TRAFFIC", "交通桥", ["A4_TRAFFIC_WORK_BRIDGE", "A4_TRAFFIC_BRIDGE"]),
        SectionDef("A4_SLOPE", "边坡", ["A4_SLOPE_LEFT", "A4_SLOPE_RIGHT"]),
        SectionDef("A4_OTHER_SECTION", "其他", ["A4_OTHER"]),
    ],
    "A5": [
        SectionDef("A5_INLET", "进口段", ["A5_INLET_LEFT_WALL", "A5_INLET_RIGHT_WALL", "A5_INLET_FLOOR"]),
        SectionDef("A5_TUNNEL", "隧洞段", ["A5_TUNNEL_GATE_SHAFT", "A5_TUNNEL_CROWN", "A5_TUNNEL_SIDEWALL", "A5_TUNNEL_FLOOR"]),
        SectionDef(
            "A5_GATE",
            "闸门系统",
            ["A5_GATE_TRASH_RACK", "A5_GATE_MAINT", "A5_GATE_MAINT_SLOT", "A5_GATE_WORK", "A5_GATE_WORK_SLOT", "A5_GATE_VENT"],
        ),
        SectionDef("A5_HOIST", "启闭系统", ["A5_HOIST_HOUSE", "A5_HOIST_MACHINE", "A5_HOIST_POWER", "A5_BACKUP_POWER"]),
        SectionDef("A5_OUTLET", "出口段", ["A5_OUTLET_LEFT_WALL", "A5_OUTLET_RIGHT_WALL", "A5_OUTLET_FLOOR", "A5_OUTLET_ENERGY"]),
        SectionDef("A5_TAIL", "尾水", ["A5_TAIL_CHANNEL", "A5_TAIL_RIVER"]),
        SectionDef("A5_OTHER_SECTION", "其他", ["A5_OTHER"]),
    ],
    "A6": [
        SectionDef("A6_INLET", "进口段", ["A6_INLET_LEFT_WALL", "A6_INLET_RIGHT_WALL", "A6_INLET_FLOOR"]),
        SectionDef("A6_TUNNEL", "洞身", ["A6_TUNNEL_GATE_SHAFT", "A6_TUNNEL_CROWN", "A6_TUNNEL_SIDEWALL", "A6_TUNNEL_FLOOR"]),
        SectionDef(
            "A6_GATE",
            "闸门系统",
            ["A6_GATE_TRASH_RACK", "A6_GATE_MAINT", "A6_GATE_MAINT_SLOT", "A6_GATE_WORK", "A6_GATE_WORK_SLOT", "A6_GATE_VENT"],
        ),
        SectionDef("A6_HOIST", "启闭系统", ["A6_HOIST_HOUSE", "A6_HOIST_MACHINE", "A6_HOIST_POWER", "A6_BACKUP_POWER"]),
        SectionDef("A6_OUTLET", "出口段", ["A6_OUTLET_LEFT_WALL", "A6_OUTLET_RIGHT_WALL", "A6_OUTLET_FLOOR", "A6_OUTLET_ENERGY"]),
        SectionDef("A6_TAIL", "尾水", ["A6_TAIL_CHANNEL", "A6_TAIL_RIVER"]),
        SectionDef("A6_OTHER_SECTION", "其他", ["A6_OTHER"]),
    ],
    "A7": [
        SectionDef("A7_ORG", "组织机构", ["A7_ORG_STRUCTURE", "A7_ORG_DEPARTMENT"]),
        SectionDef("A7_TEAM", "队伍建设", ["A7_TEAM_ADMIN", "A7_TEAM_TECH"]),
        SectionDef("A7_SYSTEM", "制度体系", ["A7_SYSTEM_TYPE", "A7_SYSTEM_EXECUTION"]),
        SectionDef("A7_OFFICE", "办公条件", ["A7_OFFICE_AREA", "A7_OFFICE_SAFETY"]),
        SectionDef("A7_EQUIP", "设备设施", ["A7_EQUIP_COMPUTER", "A7_EQUIP_PRINTER", "A7_EQUIP_MONITOR", "A7_EQUIP_FURNITURE"]),
        SectionDef("A7_HYDRO", "水雨情测报", ["A7_HYDRO_WATER", "A7_HYDRO_RAIN"]),
        SectionDef(
            "A7_MONITOR",
            "安全监测",
            ["A7_MONITOR_DEFORM", "A7_MONITOR_SEEPAGE", "A7_MONITOR_STRESS", "A7_MONITOR_TEMP", "A7_MONITOR_QUAKE", "A7_MONITOR_ENV", "A7_MONITOR_OTHER", "A7_MONITOR_DATA"],
        ),
        SectionDef("A7_ROAD", "交通保障", ["A7_ROAD_FLOOD_ACCESS", "A7_ROAD_EXTERNAL"]),
        SectionDef("A7_VEHICLE", "车辆设备", ["A7_VEHICLE_OFFICE", "A7_VEHICLE_FLOOD", "A7_VEHICLE_BOAT"]),
        SectionDef("A7_MATERIAL", "防汛物资", ["A7_MATERIAL_SOIL", "A7_MATERIAL_WOOD", "A7_MATERIAL_STEEL", "A7_MATERIAL_BAG", "A7_MATERIAL_LIGHT", "A7_MATERIAL_OTHER"]),
        SectionDef("A7_COMM", "通信预警", ["A7_COMM_PHONE", "A7_COMM_SAT", "A7_COMM_RADIO", "A7_COMM_MOBILE"]),
        SectionDef("A7_ALARM", "报警设施", ["A7_ALARM_UP", "A7_ALARM_HUB", "A7_ALARM_DOWN"]),
        SectionDef("A7_POWER", "供电照明", ["A7_POWER_HUB", "A7_LIGHT_HUB"]),
        SectionDef("A7_MAINT", "检维修", ["A7_MAINT_MACHINE", "A7_MAINT_MATERIAL"]),
        SectionDef("A7_DISPATCH", "调度运行", ["A7_DISPATCH_CONTENT", "A7_DISPATCH_TRAINING"]),
        SectionDef("A7_EMERGENCY", "应急管理", ["A7_EMERGENCY_CONTENT", "A7_EMERGENCY_RISK_MAP", "A7_EMERGENCY_VALIDITY", "A7_EMERGENCY_DRILL"]),
        SectionDef("A7_OMS", "OMS 管理", ["A7_OMS_CONTENT", "A7_OMS_TRAINING"]),
        SectionDef("A7_OTHER_SECTION", "其他", ["A7_OTHER"]),
    ],
    "A8": [
        SectionDef("A8_UP", "上游影响", ["A8_UP_RESERVOIR", "A8_UP_HYDRO", "A8_UP_GATE", "A8_UP_PUMP", "A8_UP_POND", "A8_UP_BEACH_DAM"]),
        SectionDef(
            "A8_AREA",
            "库区及近坝区",
            [
                "A8_AREA_SEEPAGE",
                "A8_AREA_GROUNDWATER",
                "A8_AREA_ROAD",
                "A8_AREA_NEARBANK_SLOPE",
                "A8_AREA_LANDSLIDE",
                "A8_AREA_SEDIMENT",
                "A8_AREA_ICE",
                "A8_AREA_RESIDENT",
                "A8_AREA_POLLUTION",
                "A8_AREA_VEGETATION",
                "A8_AREA_OTHER",
            ],
        ),
        SectionDef(
            "A8_DOWN",
            "下游影响",
            [
                "A8_DOWN_RESERVOIR",
                "A8_DOWN_HYDRO",
                "A8_DOWN_BEACH_DAM",
                "A8_DOWN_POND",
                "A8_DOWN_DIKE",
                "A8_DOWN_GATE",
                "A8_DOWN_PUMP",
                "A8_DOWN_FLOOD_AREA",
                "A8_DOWN_SECTION",
                "A8_DOWN_BRIDGE",
                "A8_DOWN_PIPELINE",
                "A8_DOWN_VILLAGE",
                "A8_DOWN_TOWN",
                "A8_DOWN_FACTORY",
                "A8_DOWN_POLLUTION",
                "A8_DOWN_SCHOOL_HOSPITAL",
                "A8_DOWN_LANDSCAPE",
                "A8_DOWN_ROAD",
                "A8_DOWN_SHELTER",
                "A8_DOWN_OTHER",
            ],
        ),
    ],
}


def _leaf_name(item_code: str) -> str:
    if item_code not in LEAF_NAME_MAP:
        raise ValueError(f"missing chinese name mapping for item_code={item_code}")
    return LEAF_NAME_MAP[item_code]


LEAF_NAME_MAP: dict[str, str] = {
    # A1
    "A1_BASIC_RES_NAME": "水库名称",
    "A1_BASIC_DESC": "水库名称及基本情况描述",
    "A1_HUB_MAIN_STRUCTURES": "枢纽工程主要建筑物",
    "A1_FLOOD_PROTECT_OBJ": "水库防洪保护对象",
    "A1_CHECK_TIME": "检查时间",
    "A1_WEATHER": "天气",
    "A1_WATER_LEVEL": "检查时库水位/m",
    "A1_STORAGE": "检查时库容/m³",
    "A1_INSPECTORS": "检查人员",
    "A1_MAIN_PROBLEM_DESC": "现场检查发现的主要问题描述",
    # A2
    "A2_CREST_ROAD": "坝顶路面",
    "A2_CREST_DRAIN": "坝顶排水设施",
    "A2_CREST_WAVE_WALL": "防浪墙",
    "A2_BODY_FILL": "坝体填筑体",
    "A2_BODY_APPEARANCE": "坝体表观",
    "A2_BODY_UP_PROTECT": "上游坝坡护坡设施",
    "A2_BODY_UP_CUSHION": "上游坝坡垫层",
    "A2_BODY_UP_FILTER": "上游坝坡反滤层",
    "A2_BODY_UP_DRAIN": "上游坝坡排水设施",
    "A2_BODY_DOWN_PROTECT": "下游坝坡护坡设施",
    "A2_BODY_DOWN_CUSHION": "下游坝坡垫层",
    "A2_BODY_DOWN_FILTER": "下游坝坡反滤层",
    "A2_BODY_DOWN_DRAIN": "下游坝坡排水设施",
    "A2_FOUND_UP": "坝基上游",
    "A2_FOUND_DOWN": "坝基下游",
    "A2_FOUND_CUTOFF": "坝基防渗体",
    "A2_ABUT_LEFT": "左坝肩",
    "A2_ABUT_RIGHT": "右坝肩",
    "A2_DOWN_GROUND_DITCH": "下游地面排水沟",
    "A2_DOWN_GROUND_CHANNEL": "下游地面排水渠",
    "A2_NEARBANK_LEFT": "左岸近坝库岸",
    "A2_NEARBANK_RIGHT": "右岸近坝库岸",
    "A2_OTHER": "其他",
    # A3
    "A3_CREST_ROAD": "坝顶路面",
    "A3_CREST_DRAIN": "坝顶排水设施",
    "A3_BODY_CONCRETE": "坝体混凝土（浆砌石）结构",
    "A3_BODY_APPEARANCE": "坝体表观",
    "A3_BODY_UP_FACE": "上游坝面",
    "A3_BODY_DOWN_FACE": "下游坝面",
    "A3_BODY_DRAIN": "坝体排水设施",
    "A3_BODY_GALLERY": "坝体廊道",
    "A3_FOUND_UP": "坝基上游",
    "A3_FOUND_DOWN": "坝基下游",
    "A3_FOUND_CURTAIN": "坝基帷幕",
    "A3_FOUND_DRAIN": "坝基排水设施",
    "A3_ABUT_LEFT": "左坝肩",
    "A3_ABUT_RIGHT": "右坝肩",
    "A3_DOWN_GROUND_DITCH": "下游地面排水沟",
    "A3_DOWN_GROUND_CHANNEL": "下游地面排水渠",
    "A3_NEARBANK_LEFT": "左岸近坝库岸",
    "A3_NEARBANK_RIGHT": "右岸近坝库岸",
    "A3_OTHER": "其他",
    # A4
    "A4_INLET_LEFT_WALL": "进口左边墙",
    "A4_INLET_RIGHT_WALL": "进口右边墙",
    "A4_INLET_FLOOR": "进口底板",
    "A4_CTRL_LEFT_WALL": "控制段左边墙",
    "A4_CTRL_RIGHT_WALL": "控制段右边墙",
    "A4_CTRL_PIER": "控制段闸墩",
    "A4_CTRL_CORBEL": "控制段牛腿",
    "A4_CTRL_FLOOR": "控制段底板",
    "A4_CTRL_WEIR": "控制段堰体",
    "A4_CTRL_TRASH_RACK": "控制段拦污栅",
    "A4_GATE_MAINT": "检修闸门",
    "A4_GATE_MAINT_SLOT": "检修闸门门槽",
    "A4_GATE_WORK": "工作闸门",
    "A4_GATE_WORK_SLOT": "工作闸门门槽",
    "A4_GATE_VENT": "闸门通气孔",
    "A4_HOIST_HOUSE": "启闭房（塔）",
    "A4_HOIST_MACHINE": "启闭机",
    "A4_HOIST_CONTROL": "启闭控制系统",
    "A4_HOIST_POWER": "启闭供电系统",
    "A4_BACKUP_POWER": "备用电源",
    "A4_CHUTE_LEFT_WALL": "泄槽左边墙",
    "A4_CHUTE_RIGHT_WALL": "泄槽右边墙",
    "A4_CHUTE_FLOOR": "泄槽底板",
    "A4_ENERGY_BUCKET": "挑流鼻坎",
    "A4_ENERGY_BASIN": "消力池",
    "A4_ENERGY_FLOOR": "消能段底板",
    "A4_ENERGY_DROP": "消能跌坎",
    "A4_TAIL_CHANNEL": "尾水渠道",
    "A4_TAIL_RIVER": "尾水河道",
    "A4_TRAFFIC_WORK_BRIDGE": "检修桥",
    "A4_TRAFFIC_BRIDGE": "交通桥",
    "A4_SLOPE_LEFT": "左边坡",
    "A4_SLOPE_RIGHT": "右边坡",
    "A4_OTHER": "其他",
    # A5
    "A5_INLET_LEFT_WALL": "进口左边墙",
    "A5_INLET_RIGHT_WALL": "进口右边墙",
    "A5_INLET_FLOOR": "进口底板",
    "A5_TUNNEL_GATE_SHAFT": "闸井",
    "A5_TUNNEL_CROWN": "洞顶",
    "A5_TUNNEL_SIDEWALL": "洞侧墙",
    "A5_TUNNEL_FLOOR": "洞底板",
    "A5_GATE_TRASH_RACK": "拦污栅",
    "A5_GATE_MAINT": "检修闸门",
    "A5_GATE_MAINT_SLOT": "检修闸门门槽",
    "A5_GATE_WORK": "工作闸门",
    "A5_GATE_WORK_SLOT": "工作闸门门槽",
    "A5_GATE_VENT": "闸门通气孔",
    "A5_HOIST_HOUSE": "启闭房（塔）",
    "A5_HOIST_MACHINE": "启闭机",
    "A5_HOIST_POWER": "启闭供电系统",
    "A5_BACKUP_POWER": "备用电源",
    "A5_OUTLET_LEFT_WALL": "出口左边墙",
    "A5_OUTLET_RIGHT_WALL": "出口右边墙",
    "A5_OUTLET_FLOOR": "出口底板",
    "A5_OUTLET_ENERGY": "出口消能设施",
    "A5_TAIL_CHANNEL": "尾水渠道",
    "A5_TAIL_RIVER": "尾水河道",
    "A5_OTHER": "其他",
    # A6
    "A6_INLET_LEFT_WALL": "进口左边墙",
    "A6_INLET_RIGHT_WALL": "进口右边墙",
    "A6_INLET_FLOOR": "进口底板",
    "A6_TUNNEL_GATE_SHAFT": "闸井",
    "A6_TUNNEL_CROWN": "洞顶",
    "A6_TUNNEL_SIDEWALL": "洞侧墙",
    "A6_TUNNEL_FLOOR": "洞底板",
    "A6_GATE_TRASH_RACK": "拦污栅",
    "A6_GATE_MAINT": "检修闸门",
    "A6_GATE_MAINT_SLOT": "检修闸门门槽",
    "A6_GATE_WORK": "工作闸门",
    "A6_GATE_WORK_SLOT": "工作闸门门槽",
    "A6_GATE_VENT": "闸门通气孔",
    "A6_HOIST_HOUSE": "启闭房（塔）",
    "A6_HOIST_MACHINE": "启闭机",
    "A6_HOIST_POWER": "启闭供电系统",
    "A6_BACKUP_POWER": "备用电源",
    "A6_OUTLET_LEFT_WALL": "出口左边墙",
    "A6_OUTLET_RIGHT_WALL": "出口右边墙",
    "A6_OUTLET_FLOOR": "出口底板",
    "A6_OUTLET_ENERGY": "出口消能设施",
    "A6_TAIL_CHANNEL": "尾水渠道",
    "A6_TAIL_RIVER": "尾水河道",
    "A6_OTHER": "其他",
    # A7
    "A7_ORG_STRUCTURE": "组织机构",
    "A7_ORG_DEPARTMENT": "部门设置",
    "A7_TEAM_ADMIN": "管理队伍",
    "A7_TEAM_TECH": "技术队伍配置",
    "A7_SYSTEM_TYPE": "管理制度",
    "A7_SYSTEM_EXECUTION": "制度执行情况",
    "A7_OFFICE_AREA": "办公场所",
    "A7_OFFICE_SAFETY": "办公安全条件",
    "A7_EQUIP_COMPUTER": "计算机设备",
    "A7_EQUIP_PRINTER": "打印设备",
    "A7_EQUIP_MONITOR": "监测终端设备",
    "A7_EQUIP_FURNITURE": "办公家具",
    "A7_HYDRO_WATER": "水位测报设施",
    "A7_HYDRO_RAIN": "雨量测报设施",
    "A7_MONITOR_DEFORM": "变形监测设施",
    "A7_MONITOR_SEEPAGE": "渗流监测设施",
    "A7_MONITOR_STRESS": "应力应变监测设施",
    "A7_MONITOR_TEMP": "温度监测设施",
    "A7_MONITOR_QUAKE": "地震监测设施",
    "A7_MONITOR_ENV": "环境监测设施",
    "A7_MONITOR_OTHER": "其他监测设施",
    "A7_MONITOR_DATA": "监测资料整编",
    "A7_ROAD_FLOOD_ACCESS": "防汛抢险道路",
    "A7_ROAD_EXTERNAL": "对外交通道路",
    "A7_VEHICLE_OFFICE": "办公车辆",
    "A7_VEHICLE_FLOOD": "防汛抢险车辆",
    "A7_VEHICLE_BOAT": "抢险船只",
    "A7_MATERIAL_SOIL": "土料",
    "A7_MATERIAL_WOOD": "木材",
    "A7_MATERIAL_STEEL": "钢材",
    "A7_MATERIAL_BAG": "编织袋",
    "A7_MATERIAL_LIGHT": "照明设备",
    "A7_MATERIAL_OTHER": "其他防汛物资",
    "A7_COMM_PHONE": "固定电话",
    "A7_COMM_SAT": "卫星电话",
    "A7_COMM_RADIO": "对讲机",
    "A7_COMM_MOBILE": "移动通信",
    "A7_ALARM_UP": "上游预警设施",
    "A7_ALARM_HUB": "枢纽区预警设施",
    "A7_ALARM_DOWN": "下游预警设施",
    "A7_POWER_HUB": "枢纽区供电设施",
    "A7_LIGHT_HUB": "枢纽区照明设施",
    "A7_MAINT_MACHINE": "检维修机械设备",
    "A7_MAINT_MATERIAL": "检维修材料",
    "A7_DISPATCH_CONTENT": "调度规程内容",
    "A7_DISPATCH_TRAINING": "调度培训与演练",
    "A7_EMERGENCY_CONTENT": "应急预案内容",
    "A7_EMERGENCY_RISK_MAP": "风险图编制",
    "A7_EMERGENCY_VALIDITY": "预案有效性",
    "A7_EMERGENCY_DRILL": "应急演练",
    "A7_OMS_CONTENT": "OMS内容",
    "A7_OMS_TRAINING": "OMS培训",
    "A7_OTHER": "其他管理设施",
    # A8
    "A8_UP_RESERVOIR": "上游水库",
    "A8_UP_HYDRO": "上游水电站",
    "A8_UP_GATE": "上游闸坝",
    "A8_UP_PUMP": "上游泵站",
    "A8_UP_POND": "上游山塘",
    "A8_UP_BEACH_DAM": "上游塘坝",
    "A8_AREA_SEEPAGE": "库区渗漏",
    "A8_AREA_GROUNDWATER": "库区地下水异常",
    "A8_AREA_ROAD": "库区道路条件",
    "A8_AREA_NEARBANK_SLOPE": "近坝岸坡稳定",
    "A8_AREA_LANDSLIDE": "库区滑坡体",
    "A8_AREA_SEDIMENT": "库区淤积",
    "A8_AREA_ICE": "库区冰冻影响",
    "A8_AREA_RESIDENT": "库区居民点",
    "A8_AREA_POLLUTION": "库区污染源",
    "A8_AREA_VEGETATION": "库区植被",
    "A8_AREA_OTHER": "库区其他",
    "A8_DOWN_RESERVOIR": "下游水库",
    "A8_DOWN_HYDRO": "下游水电站",
    "A8_DOWN_BEACH_DAM": "下游塘坝",
    "A8_DOWN_POND": "下游山塘",
    "A8_DOWN_DIKE": "下游堤防",
    "A8_DOWN_GATE": "下游闸坝",
    "A8_DOWN_PUMP": "下游泵站",
    "A8_DOWN_FLOOD_AREA": "下游行洪区",
    "A8_DOWN_SECTION": "下游河道断面",
    "A8_DOWN_BRIDGE": "下游跨河桥梁",
    "A8_DOWN_PIPELINE": "下游跨河管线",
    "A8_DOWN_VILLAGE": "下游村庄",
    "A8_DOWN_TOWN": "下游城镇",
    "A8_DOWN_FACTORY": "下游工矿企业",
    "A8_DOWN_POLLUTION": "下游污染源",
    "A8_DOWN_SCHOOL_HOSPITAL": "下游学校医院",
    "A8_DOWN_LANDSCAPE": "下游景区",
    "A8_DOWN_ROAD": "下游交通干线",
    "A8_DOWN_SHELTER": "下游避险场所",
    "A8_DOWN_OTHER": "下游其他",
}


def _attachment_enabled(chapter_code: str) -> bool:
    return chapter_code == "A7"


def build_template_items() -> list[dict]:
    items: list[dict] = []
    chapter_order = 0

    for chapter_code, chapter_name in CHAPTERS.items():
        chapter_order += 1
        items.append(
            {
                "item_id": f"tmpl_{chapter_code.lower()}",
                "item_code": chapter_code,
                "chapter_code": chapter_code,
                "parent_code": None,
                "item_name": chapter_name,
                "item_type": "chapter",
                "applicable_dam_type": CHAPTER_DAM_TYPES[chapter_code],
                "supports_photo": False,
                "supports_audio": False,
                "supports_location": False,
                "supports_attachment": False,
                "sort_order": chapter_order * 1000,
            }
        )

        section_order = 0
        for section in TEMPLATE_STRUCTURE[chapter_code]:
            section_order += 1
            section_sort = chapter_order * 1000 + section_order * 100
            items.append(
                {
                    "item_id": f"tmpl_{section.code.lower()}",
                    "item_code": section.code,
                    "chapter_code": chapter_code,
                    "parent_code": chapter_code,
                    "item_name": section.name,
                    "item_type": "section",
                    "applicable_dam_type": CHAPTER_DAM_TYPES[chapter_code],
                    "supports_photo": False,
                    "supports_audio": False,
                    "supports_location": False,
                    "supports_attachment": False,
                    "sort_order": section_sort,
                }
            )

            leaf_order = 0
            for leaf_code in section.leaf_codes:
                leaf_order += 1
                items.append(
                    {
                        "item_id": f"tmpl_{leaf_code.lower()}",
                        "item_code": leaf_code,
                        "chapter_code": chapter_code,
                        "parent_code": section.code,
                        "item_name": _leaf_name(leaf_code),
                        "item_type": "inspection_item",
                        "applicable_dam_type": CHAPTER_DAM_TYPES[chapter_code],
                        "supports_photo": chapter_code != "A1",
                        "supports_audio": chapter_code != "A1",
                        "supports_location": chapter_code != "A1",
                        "supports_attachment": _attachment_enabled(chapter_code),
                        "sort_order": section_sort + leaf_order,
                    }
                )

    return items


def main() -> None:
    items = build_template_items()
    out_path = Path(__file__).resolve().parents[1] / "seeds" / "inspection_template_items.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "seed_version": "v1",
        "item_count": len(items),
        "items": items,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"generated: {out_path}")
    print(f"item_count: {len(items)}")


if __name__ == "__main__":
    main()
