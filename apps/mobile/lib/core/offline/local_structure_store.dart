class LocalStructureStore {
  LocalStructureStore._();

  static const Map<String, Map<String, Object>> objectTypeMeta = {
    'main_dam': {
      'label': '主坝',
      'category': 'water_retaining',
      'template': 'main_dam',
      'single': true,
    },
    'aux_dam': {
      'label': '副坝',
      'category': 'water_retaining',
      'template': 'aux_dam',
      'single': false,
    },
    'spillway': {
      'label': '溢洪道',
      'category': 'water_releasing',
      'template': 'spillway',
      'single': true,
    },
    'outlet_tunnel': {
      'label': '输水洞',
      'category': 'water_conveyance',
      'template': 'outlet_tunnel',
      'single': false,
    },
    'spill_tunnel': {
      'label': '泄洪洞',
      'category': 'water_releasing',
      'template': 'spill_tunnel',
      'single': false,
    },
    'power_tunnel': {
      'label': '发电洞',
      'category': 'power_generation',
      'template': 'power_tunnel',
      'single': false,
    },
    'admin_facility': {
      'label': '管理设施',
      'category': 'management',
      'template': 'admin_facility',
      'single': false,
    },
    'updownstream_env': {
      'label': '上下游环境对象',
      'category': 'environment',
      'template': 'updownstream_env',
      'single': false,
    },
    'custom': {
      'label': '自定义对象',
      'category': 'other',
      'template': 'main_dam',
      'single': false,
    },
  };

  static const Map<String, List<Map<String, Object>>> partTemplates = {
    'main_dam': [
      {'part_code': 'dam_crest', 'part_name': '坝顶', 'sort_order': 10},
      {'part_code': 'upstream_face', 'part_name': '上游面', 'sort_order': 20},
      {'part_code': 'downstream_face', 'part_name': '下游面', 'sort_order': 30},
      {'part_code': 'dam_abutment', 'part_name': '坝肩', 'sort_order': 40},
      {'part_code': 'dam_foundation', 'part_name': '坝基附近', 'sort_order': 50},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'aux_dam': [
      {'part_code': 'dam_crest', 'part_name': '坝顶', 'sort_order': 10},
      {'part_code': 'upstream_face', 'part_name': '上游面', 'sort_order': 20},
      {'part_code': 'downstream_face', 'part_name': '下游面', 'sort_order': 30},
      {'part_code': 'dam_abutment', 'part_name': '坝肩', 'sort_order': 40},
      {'part_code': 'dam_foundation', 'part_name': '坝基附近', 'sort_order': 50},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'spillway': [
      {'part_code': 'inlet', 'part_name': '进口段', 'sort_order': 10},
      {'part_code': 'control', 'part_name': '控制段', 'sort_order': 20},
      {'part_code': 'chute', 'part_name': '泄槽段', 'sort_order': 30},
      {'part_code': 'energy_dissipation', 'part_name': '消能段', 'sort_order': 40},
      {'part_code': 'tailwater', 'part_name': '尾水段', 'sort_order': 50},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'outlet_tunnel': [
      {'part_code': 'inlet', 'part_name': '进口段', 'sort_order': 10},
      {'part_code': 'tunnel_body', 'part_name': '洞身段', 'sort_order': 20},
      {'part_code': 'outlet', 'part_name': '出口段', 'sort_order': 30},
      {'part_code': 'hoist', 'part_name': '启闭设施', 'sort_order': 40},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'spill_tunnel': [
      {'part_code': 'inlet', 'part_name': '进口段', 'sort_order': 10},
      {'part_code': 'tunnel_body', 'part_name': '洞身段', 'sort_order': 20},
      {'part_code': 'outlet', 'part_name': '出口段', 'sort_order': 30},
      {'part_code': 'hoist', 'part_name': '启闭设施', 'sort_order': 40},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'power_tunnel': [
      {'part_code': 'inlet', 'part_name': '进口段', 'sort_order': 10},
      {'part_code': 'tunnel_body', 'part_name': '洞身段', 'sort_order': 20},
      {'part_code': 'outlet', 'part_name': '出口段', 'sort_order': 30},
      {'part_code': 'hoist', 'part_name': '启闭设施', 'sort_order': 40},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'admin_facility': [
      {'part_code': 'main_building', 'part_name': '主体建筑', 'sort_order': 10},
      {'part_code': 'equipment', 'part_name': '设备设施', 'sort_order': 20},
      {'part_code': 'power_lighting', 'part_name': '电源照明', 'sort_order': 30},
      {'part_code': 'communication_monitor', 'part_name': '通信监测', 'sort_order': 40},
      {'part_code': 'surrounding_road', 'part_name': '周边道路', 'sort_order': 50},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
    'updownstream_env': [
      {'part_code': 'bank', 'part_name': '库岸', 'sort_order': 10},
      {'part_code': 'river_channel', 'part_name': '河道', 'sort_order': 20},
      {'part_code': 'slope', 'part_name': '岸坡', 'sort_order': 30},
      {'part_code': 'bridge_path', 'part_name': '桥梁/通道', 'sort_order': 40},
      {'part_code': 'hazard_zone', 'part_name': '障碍物/隐患区', 'sort_order': 50},
      {'part_code': 'other', 'part_name': '其他', 'sort_order': 90},
    ],
  };

  static Map<String, Object> getObjectMeta(String objectType) =>
      objectTypeMeta[objectType] ?? objectTypeMeta['custom']!;

  static List<String> buildDefaultInstanceNames(String objectType, int count) {
    final meta = getObjectMeta(objectType);
    final label = meta['label']!.toString();
    final isSingle = meta['single'] == true;
    if (isSingle) return [label];
    if (count <= 1) return ['${label}1'];
    return List.generate(count, (index) => '$label${index + 1}');
  }

  static List<Map<String, Object>> listStructurePartTemplates(String objectType) {
    final rows = partTemplates[objectType] ?? const [];
    return rows
        .map(
          (row) => {
            'template_code': objectType,
            'object_type': objectType,
            'part_code': row['part_code']!,
            'part_name': row['part_name']!,
            'sort_order': row['sort_order']!,
          },
        )
        .toList();
  }

  static String? getPartName(String objectType, String partCode) {
    for (final row in partTemplates[objectType] ?? const []) {
      if (row['part_code'] == partCode) {
        return row['part_name']!.toString();
      }
    }
    return null;
  }
}
