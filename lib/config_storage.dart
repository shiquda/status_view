import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_model.dart';

class ConfigStorage {
  static const String _configsKey = 'saved_configs';

  // 保存配置列表
  static Future<bool> saveConfigs(List<StatusConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedConfigs =
        configs.map((config) => jsonEncode(config.toMap())).toList();

    return await prefs.setStringList(_configsKey, encodedConfigs);
  }

  // 添加单个配置
  static Future<bool> addConfig(StatusConfig config) async {
    final configs = await loadConfigs();

    // 检查是否已存在相同名称的配置
    final index = configs.indexWhere((c) => c.name == config.name);
    if (index >= 0) {
      configs[index] = config; // 更新现有配置
    } else {
      configs.add(config); // 添加新配置
    }

    return await saveConfigs(configs);
  }

  // 加载所有配置
  static Future<List<StatusConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encodedConfigs = prefs.getStringList(_configsKey);

    if (encodedConfigs == null || encodedConfigs.isEmpty) {
      return [];
    }

    return encodedConfigs
        .map((encoded) => StatusConfig.fromMap(jsonDecode(encoded)))
        .toList();
  }

  // 删除配置
  static Future<bool> deleteConfig(String configName) async {
    final configs = await loadConfigs();
    configs.removeWhere((config) => config.name == configName);
    return await saveConfigs(configs);
  }

  // 清除所有配置
  static Future<bool> clearConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_configsKey);
  }
}
