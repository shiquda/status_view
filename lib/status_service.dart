import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config_model.dart';

class StatusResult {
  final String value;
  final bool isSuccess;
  final String? error;
  final DateTime timestamp;

  StatusResult({required this.value, required this.isSuccess, this.error})
    : timestamp = DateTime.now();

  // 根据配置的格式化字符串返回格式化后的状态
  String formattedValue(String format) {
    if (isSuccess) {
      return format.replaceAll('%s', value);
    } else {
      return '错误: $error';
    }
  }
}

class StatusService {
  // 缓存状态结果，键为配置名称
  static final Map<String, StatusResult> _resultCache = {};

  // 获取缓存的状态结果
  static StatusResult? getCachedResult(String configName) {
    return _resultCache[configName];
  }

  // 根据配置获取状态
  static Future<StatusResult> fetchStatus(StatusConfig config) async {
    try {
      debugPrint('开始请求URL: ${config.url}');

      // 发送HTTP请求
      final response = await http
          .get(Uri.parse(config.url))
          .timeout(const Duration(seconds: 10));

      debugPrint('收到响应状态码: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 请求成功，解析JSON
        try {
          final jsonData = jsonDecode(response.body);
          debugPrint('JSON解析成功');

          // 使用配置的JSON语法路径提取值
          final value = _extractValueFromJson(jsonData, config.jsonSyntax);
          debugPrint('提取的值: $value');

          // 创建成功结果并缓存
          final result = StatusResult(value: value.toString(), isSuccess: true);

          _resultCache[config.name] = result;
          return result;
        } catch (e) {
          debugPrint('JSON解析错误: $e');
          final result = StatusResult(
            value: '',
            isSuccess: false,
            error: 'JSON解析失败: $e',
          );

          _resultCache[config.name] = result;
          return result;
        }
      } else {
        // HTTP请求失败
        debugPrint('HTTP请求失败，状态码: ${response.statusCode}');
        final result = StatusResult(
          value: '',
          isSuccess: false,
          error:
              '请求失败 (${response.statusCode}): ${response.reasonPhrase ?? "未知错误"}',
        );

        _resultCache[config.name] = result;
        return result;
      }
    } catch (e) {
      // 网络或其他错误
      debugPrint('请求错误类型: ${e.runtimeType}');
      debugPrint('请求错误详情: $e');

      String errorMessage;

      // 针对特定类型的错误提供更友好的提示
      if (e.toString().contains('SocketException')) {
        errorMessage = '网络连接错误: 无法连接到服务器，请检查网络设置或URL是否正确';
      } else if (e.toString().contains('Certificate')) {
        errorMessage = '安全连接错误: 证书验证失败，可能需要配置应用信任设置';
      } else if (e.toString().contains('timeout')) {
        errorMessage = '连接超时: 服务器响应时间过长';
      } else {
        errorMessage = '连接错误: $e';
      }

      final result = StatusResult(
        value: '',
        isSuccess: false,
        error: errorMessage,
      );

      _resultCache[config.name] = result;
      return result;
    }
  }

  // 从JSON对象中根据路径提取值
  // 支持简化的JSONPath格式：$.key1.key2[0].key3
  static dynamic _extractValueFromJson(dynamic json, String path) {
    if (path.isEmpty) return json;

    // 处理JSONPath格式
    if (path.startsWith(r'$')) {
      return _parseJsonPath(json, path);
    }

    // 简单的直接属性访问
    final keys = path.split('.');
    dynamic result = json;

    for (final key in keys) {
      if (result == null) return null;

      if (result is Map) {
        result = result[key];
      } else {
        throw Exception('无法从非对象类型中提取"$key"，当前值: $result');
      }
    }

    return result;
  }

  // 解析JSONPath格式
  static dynamic _parseJsonPath(dynamic json, String path) {
    // 移除开头的 $
    path = path.substring(1);
    if (path.isEmpty || path == '.') return json;

    // 如果以点开头，移除点
    if (path.startsWith('.')) path = path.substring(1);

    dynamic current = json;

    // 匹配数组索引 [n] 和普通属性
    final regexIndex = RegExp(r'(\[\d+\])');

    // 分割路径为段，同时保留数组索引标记
    List<String> segments = [];
    int lastStart = 0;

    // 处理带有数组索引的路径
    for (var match in regexIndex.allMatches(path)) {
      if (match.start > lastStart) {
        // 添加前面的属性路径段
        segments.add(path.substring(lastStart, match.start));
      }
      // 添加数组索引段
      segments.add(match.group(0)!);
      lastStart = match.end;
    }

    // 添加最后一段
    if (lastStart < path.length) {
      segments.add(path.substring(lastStart));
    }

    // 如果没有匹配到任何索引，按普通属性路径处理
    if (segments.isEmpty) {
      segments = path.split('.');
    }

    // 遍历每个路径段
    for (var segment in segments) {
      if (current == null) {
        return null;
      }

      // 处理数组索引
      if (segment.startsWith('[') && segment.endsWith(']')) {
        // 提取索引数字
        int index = int.parse(segment.substring(1, segment.length - 1));

        if (current is List) {
          if (index >= 0 && index < current.length) {
            current = current[index];
          } else {
            throw Exception('数组索引超出范围: $index，数组长度: ${current.length}');
          }
        } else {
          throw Exception('无法对非数组类型使用索引: $current');
        }
      }
      // 处理普通属性，可能包含点分隔符
      else {
        for (var key in segment.split('.')) {
          if (key.isEmpty) continue;

          if (current is Map) {
            current = current[key];
          } else {
            throw Exception('无法从非对象类型中提取"$key"，当前值: $current');
          }
        }
      }
    }

    return current;
  }
}
