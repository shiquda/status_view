import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'config_model.dart';
import 'config_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 设置分组 - 数据管理
              _buildSettingGroup(
                title: '数据管理',
                children: [
                  _buildSettingItem(
                    icon: Icons.backup,
                    title: '备份配置',
                    subtitle: '导出所有监控配置到文件',
                    onTap: _exportConfigs,
                  ),
                  _buildSettingItem(
                    icon: Icons.restore,
                    title: '恢复配置',
                    subtitle: '从备份文件导入监控配置',
                    onTap: _importConfigs,
                  ),
                  _buildSettingItem(
                    icon: Icons.delete_forever,
                    title: '重置所有配置',
                    subtitle: '删除所有监控配置',
                    isDestructive: true,
                    onTap: _resetAllConfigs,
                  ),
                ],
              ),

              // 状态消息
              if (_statusMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color:
                        _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color:
                          _isSuccess
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error,
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color:
                                _isSuccess
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // 加载指示器
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // 导出配置
  Future<void> _exportConfigs() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    // 首先检查并请求权限
    if (!await _requestStoragePermission()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 获取所有配置
      final configs = await ConfigStorage.loadConfigs();
      if (configs.isEmpty) {
        _showStatus('没有找到任何配置可导出', false);
        return;
      }

      // 将配置转换为JSON
      final Map<String, dynamic> exportData = {
        'date': DateTime.now().toIso8601String(),
        'version': '1.0',
        'configs': configs.map((config) => config.toMap()).toList(),
      };
      final jsonString = jsonEncode(exportData);

      // 让用户选择保存位置
      final savedFileInfo = await _saveConfigToUserSelectedPath(jsonString);

      if (savedFileInfo != null) {
        _showStatus('配置已保存到: ${savedFileInfo['path']}', true);
        // 显示可点击的底部通知，提示用户可以分享文件
        _showShareSnackBar(savedFileInfo['path'] as String, configs.length);
      } else {
        _showStatus('保存失败', false);
      }
    } catch (e) {
      debugPrint('导出配置错误: $e');
      _showStatus('导出配置失败: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    try {
      // 在 Android 13+ 上使用新的权限模型，对其他平台保持原有逻辑
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        // Android 13+ (API 33+) 使用新的媒体权限
        if (androidInfo.version.sdkInt >= 33) {
          // 检查图片和视频权限
          final photosStatus = await Permission.photos.status;
          final videosStatus = await Permission.videos.status;

          // 如果已经有权限，直接返回成功
          if (photosStatus.isGranted && videosStatus.isGranted) {
            return true;
          }

          // 请求权限
          final photosResult = await Permission.photos.request();
          final videosResult = await Permission.videos.request();

          // 如果有任何一个权限被永久拒绝，引导用户到设置
          if (photosResult.isPermanentlyDenied ||
              videosResult.isPermanentlyDenied) {
            final goToSettings = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('需要媒体访问权限'),
                    content: const Text('此功能需要访问媒体文件的权限才能工作。请在设置中手动授予权限。'),
                    actions: [
                      TextButton(
                        child: const Text('取消'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      TextButton(
                        child: const Text('去设置'),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
            );

            if (goToSettings == true) {
              await openAppSettings();
              // 等待用户从设置返回，然后重新检查权限
              return await Permission.photos.status.isGranted &&
                  await Permission.videos.status.isGranted;
            }
            return false;
          }

          // 检查请求结果
          if (photosResult.isDenied || videosResult.isDenied) {
            _showStatus('需要媒体访问权限才能导出/导入配置', false);
            return false;
          }

          return photosResult.isGranted && videosResult.isGranted;
        }
      }

      // Android 13 以下版本或其他平台使用旧的权限逻辑
      // 检查当前权限状态
      PermissionStatus status = await Permission.storage.status;

      // 如果已经有权限，直接返回成功
      if (status.isGranted) {
        return true;
      }

      // 如果权限被永久拒绝，显示对话框引导用户到设置页面手动授权
      if (status.isPermanentlyDenied) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('需要存储权限'),
                content: const Text('此功能需要存储权限才能工作。请在设置中手动授予权限。'),
                actions: [
                  TextButton(
                    child: const Text('取消'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  TextButton(
                    child: const Text('去设置'),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
        );

        if (goToSettings == true) {
          await openAppSettings();
          // 重新检查权限状态
          return await Permission.storage.status.isGranted;
        }
        return false;
      }

      // 请求权限
      status = await Permission.storage.request();

      // 如果用户拒绝权限但没有选择"不再询问"，显示解释性提示
      if (status.isDenied) {
        _showStatus('需要存储权限才能导出/导入配置', false);
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('请求权限错误: $e');
      return false;
    }
  }

  // 显示分享提示的Snackbar
  void _showShareSnackBar(String filePath, int configCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('配置文件已保存'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: '分享',
          onPressed: () {
            // 分享文件
            Share.shareXFiles(
              [XFile(filePath)],
              subject: '状态监控配置备份',
              text: '备份包含$configCount个监控配置项',
            );
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // 使用FilePicker的saveFile方法让用户选择保存位置
  Future<Map<String, dynamic>?> _saveConfigToUserSelectedPath(
    String jsonString,
  ) async {
    try {
      // 使用目录选择方法（更稳定）
      String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );

      if (directoryPath != null) {
        final fileName =
            'status_view_backup_${DateTime.now().toIso8601String().replaceAll(':', '_')}.json';
        final filePath = '$directoryPath/$fileName';

        // 写入文件
        final file = File(filePath);
        await file.writeAsString(jsonString);
        return {'path': filePath, 'success': true};
      }

      return null; // 用户取消了目录选择
    } catch (e) {
      debugPrint('使用目录选择器保存失败: $e');
      return null;
    }
  }

  // 导入配置
  Future<void> _importConfigs() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    // 首先检查并请求权限
    if (!await _requestStoragePermission()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 使用 file_picker 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        String? jsonString;
        final file = result.files.first;

        try {
          // 首先尝试通过路径读取
          if (file.path != null) {
            final fileFromPath = File(file.path!);
            if (await fileFromPath.exists()) {
              jsonString = await fileFromPath.readAsString();
            } else {
              throw Exception('找不到文件: ${file.path}');
            }
          } else if (file.bytes != null) {
            // 如果没有路径但有字节数据（Web平台）
            jsonString = utf8.decode(file.bytes!);
          } else {
            throw Exception('无法读取文件内容');
          }
        } catch (e) {
          debugPrint('读取文件失败: $e');

          if (file.bytes != null) {
            // 尝试直接从字节读取
            jsonString = utf8.decode(file.bytes!);
          } else {
            rethrow;
          }
        }

        if (jsonString != null && jsonString.isNotEmpty) {
          await _processImportedJson(jsonString);
        } else {
          throw Exception('无法读取文件内容');
        }
      } else {
        // 用户取消文件选择
        _showStatus('已取消选择文件', true);
      }
    } catch (e) {
      debugPrint('导入配置错误: $e');
      _showStatus('导入配置失败: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 处理导入的JSON字符串
  Future<void> _processImportedJson(String jsonString) async {
    try {
      // 记录处理开始
      debugPrint('开始处理导入的JSON数据，长度: ${jsonString.length}');

      final Map<String, dynamic> importData = json.decode(jsonString);
      debugPrint('JSON解析成功，检查数据格式');

      // 验证导入数据
      if (!importData.containsKey('configs')) {
        throw Exception('不是有效的备份文件格式: 缺少configs字段');
      }

      if (importData['configs'] is! List) {
        throw Exception('不是有效的备份文件格式: configs不是列表格式');
      }

      // 提取配置
      final List configMaps = importData['configs'] as List;
      debugPrint('找到${configMaps.length}个配置项');

      if (configMaps.isEmpty) {
        throw Exception('备份文件不包含任何配置');
      }

      try {
        final List<StatusConfig> configs =
            configMaps
                .map(
                  (item) => StatusConfig.fromMap(item as Map<String, dynamic>),
                )
                .toList();

        if (configs.isEmpty) {
          throw Exception('备份文件不包含任何有效配置');
        }

        debugPrint('成功解析${configs.length}个配置，准备显示确认对话框');

        // 显示确认对话框
        bool? confirmed = await _showImportConfirmDialog(configs);
        debugPrint('用户确认结果: $confirmed');

        if (confirmed == true) {
          // 保存配置
          await ConfigStorage.saveConfigs(configs);
          _showStatus('成功导入${configs.length}个配置', true);
        } else {
          _showStatus('导入已取消', false);
        }
      } catch (e) {
        debugPrint('配置解析错误: $e');
        _showStatus('解析配置项失败: $e', false);
      }
    } catch (e) {
      debugPrint('JSON解析错误: $e');
      _showStatus('解析备份文件失败: $e', false);
    }
  }

  // 重置所有配置
  Future<void> _resetAllConfigs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认重置'),
            content: const Text('此操作将删除所有监控配置，且不可恢复，确定继续吗？'),
            actions: [
              TextButton(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text('重置', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _statusMessage = '';
      });

      try {
        await ConfigStorage.clearConfigs();
        _showStatus('已重置所有配置', true);
      } catch (e) {
        _showStatus('重置配置失败: $e', false);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 显示导入确认对话框
  Future<bool?> _showImportConfirmDialog(List<StatusConfig> configs) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认导入'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('将导入${configs.length}个配置：'),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: configs.length,
                    itemBuilder: (context, index) {
                      final config = configs[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          config.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          config.url,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('注意：同名配置将被覆盖'),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text('导入'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );
  }

  // 显示状态消息
  void _showStatus(String message, bool isSuccess) {
    setState(() {
      _statusMessage = message;
      _isSuccess = isSuccess;
    });
  }
}
