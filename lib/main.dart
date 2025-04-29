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
      final result = await StatusService.fetchStatus(config);

      // 检查组件是否还挂载
      if (!mounted) return;

      setState(() {
        _results[config.name] = result;
        _refreshingStates[config.name] = false;
      });
    } catch (e) {
      debugPrint('刷新状态错误: $e');

      if (!mounted) return;

      setState(() {
        _results[config.name] = StatusResult(
          value: '',
          isSuccess: false,
          error: '刷新失败: $e',
        );
        _refreshingStates[config.name] = false;
      });
    }
  }

  // 刷新所有状态
  Future<void> _refreshAllStatuses() async {
    for (var config in _configs) {
      await _refreshStatus(config);
    }
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
                    return _buildStatusItem(config, index);
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

  Widget _buildStatusItem(StatusConfig config, int index) {
    final isRefreshing = _refreshingStates[config.name] ?? false;
    final result = _results[config.name];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:
            result?.isSuccess == true
                ? Colors.green.shade100
                : result?.isSuccess == false
                ? Colors.red.shade100
                : Colors.blue.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _refreshStatus(config),
        onLongPress: () {
          _showOptionsDialog(config);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isRefreshing
                  ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(
                    result?.isSuccess == true
                        ? Icons.check_circle
                        : result?.isSuccess == false
                        ? Icons.error
                        : Icons.sync,
                    size: 36,
                    color:
                        result?.isSuccess == true
                            ? Colors.green
                            : result?.isSuccess == false
                            ? Colors.red
                            : Colors.blue,
                  ),
              const SizedBox(height: 8),
              Text(
                config.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result == null
                    ? '点击获取...'
                    : result.isSuccess
                    ? result.formattedValue(config.stringFormat)
                    : '错误: ${result.error?.replaceAll(RegExp(r'Exception: '), '')}',
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
            ],
          ),
        ),
      ),
    );
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
