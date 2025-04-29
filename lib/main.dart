import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'status_config.dart';
import 'config_model.dart';
import 'config_storage.dart';
import 'status_service.dart';
import 'settings_page.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Status View',
      home: const StatusViewPage(),
      theme: ThemeData(
        colorScheme: AppTheme.lightScheme,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class StatusViewPage extends StatefulWidget {
  const StatusViewPage({super.key});

  @override
  State<StatusViewPage> createState() => _StatusViewPageState();
}

class _StatusViewPageState extends State<StatusViewPage> {
  List<StatusConfig> _configs = [];
  bool _isLoading = true;
  final Map<String, bool> _refreshingStates = {};
  final Map<String, StatusResult?> _results = {};

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final configs = await ConfigStorage.loadConfigs();

      // 初始化刷新状态和结果
      final Map<String, bool> newRefreshingStates = {};
      final Map<String, StatusResult?> newResults = {};

      for (var config in configs) {
        newRefreshingStates[config.name] = false;

        // 尝试获取缓存的结果
        final cachedResult = StatusService.getCachedResult(config.name);
        newResults[config.name] = cachedResult;
      }

      setState(() {
        _configs = configs;
        _refreshingStates.addAll(newRefreshingStates);
        _results.addAll(newResults);
        _isLoading = false;
      });

      // 自动获取所有配置的状态
      if (configs.isNotEmpty) {
        _refreshAllStatuses();
      }
    } catch (e) {
      debugPrint('加载配置错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 刷新单个状态
  Future<void> _refreshStatus(StatusConfig config) async {
    // 避免重复刷新
    if (_refreshingStates[config.name] == true) return;

    setState(() {
      _refreshingStates[config.name] = true;
    });

    try {
      debugPrint('开始刷新状态: ${config.name}, URL: ${config.url}');
      final result = await StatusService.fetchStatus(config);
      debugPrint('状态刷新完成: ${config.name}, 成功: ${result.isSuccess}');

      // 检查组件是否还挂载
      if (!mounted) return;

      setState(() {
        _results[config.name] = result;
        _refreshingStates[config.name] = false;
      });
    } catch (e) {
      debugPrint('刷新状态错误: $e');

      if (!mounted) return;

      // 确保错误信息不会太长，避免UI溢出
      String errorMsg = e.toString();
      if (errorMsg.length > 100) {
        errorMsg = '${errorMsg.substring(0, 97)}...';
      }

      setState(() {
        _results[config.name] = StatusResult(
          value: '',
          isSuccess: false,
          error: '刷新失败: $errorMsg',
        );
        _refreshingStates[config.name] = false;
      });
    }
  }

  // 刷新所有状态
  Future<void> _refreshAllStatuses() async {
    // 使用Future.wait并行执行所有刷新任务
    await Future.wait(_configs.map((config) => _refreshStatus(config)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status View'),
        actions: [
          if (_configs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新所有状态',
              onPressed: () => _refreshAllStatuses(),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              if (mounted) {
                _loadConfigs();
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _configs.isEmpty
              ? const Center(
                child: Text(
                  '还没有配置，\n点击右下角 + 添加',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : RefreshIndicator(
                onRefresh: _refreshAllStatuses,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  padding: const EdgeInsets.all(16),
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    return _buildStatusCard(context, config);
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const configPage()),
          );

          // 用户返回后重新加载配置
          if (mounted) {
            _loadConfigs();
          }
        },
        backgroundColor: AppTheme.lightScheme.surface,
        tooltip: "添加Status",
        child: Icon(Icons.add, color: AppTheme.lightScheme.onSurface),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, StatusConfig config) {
    final result = _results[config.name];
    final isRefreshing = _refreshingStates[config.name] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isRefreshing) return;
          if (result != null && !result.isSuccess) {
            // 如果有错误，显示错误详情对话框
            _showErrorDetailDialog(context, config, result);
          } else {
            _refreshStatus(config);
          }
        },
        onLongPress: () => _showOptionsDialog(config),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      config.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                result == null
                    ? '点击获取...'
                    : result.isSuccess
                    ? result.formattedValue(config.stringFormat)
                    : '错误: ${_shortenError(result.error)}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      result?.isSuccess == true
                          ? Colors.green.shade700
                          : result?.isSuccess == false
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              if (result != null && !result.isSuccess)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '点击查看详情',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 截断错误信息
  String _shortenError(String? error) {
    if (error == null || error.isEmpty) return '未知错误';
    // 移除Exception:前缀
    String shortenedError = error.replaceAll(RegExp(r'Exception: '), '');
    // 截断长错误信息
    if (shortenedError.length > 50) {
      return '${shortenedError.substring(0, 47)}...';
    }
    return shortenedError;
  }

  // 显示错误详情对话框
  void _showErrorDetailDialog(
    BuildContext context,
    StatusConfig config,
    StatusResult result,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('错误详情'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '配置: ${config.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('URL: ${config.url}'),
                const SizedBox(height: 12),
                const Text(
                  '错误信息:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    result.error ?? '未知错误',
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '最后刷新: ${_formatDateTime(result.timestamp)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () {
                  Navigator.pop(context);
                  _refreshStatus(config);
                },
              ),
              TextButton(
                child: const Text('关闭'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _showOptionsDialog(StatusConfig config) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(config.name),
            content: const Text('请选择操作'),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
                onPressed: () {
                  Navigator.pop(context);
                  _refreshStatus(config);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
                onPressed: () async {
                  Navigator.pop(context); // 关闭对话框

                  // 导航到编辑页面，并传递配置
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => configPage(initialConfig: config),
                    ),
                  );

                  // 编辑完成后重新加载配置
                  if (mounted) {
                    _loadConfigs();
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('删除', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteConfig(config);
                },
              ),
            ],
          ),
    );
  }

  void _confirmDeleteConfig(StatusConfig config) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除"${config.name}"配置吗？'),
            actions: [
              TextButton(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('删除', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(context);
                  await ConfigStorage.deleteConfig(config.name);
                  if (mounted) {
                    _loadConfigs();
                  }
                },
              ),
            ],
          ),
    );
  }
}
