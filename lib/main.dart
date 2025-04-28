import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'status_config.dart';
import 'config_model.dart';
import 'config_storage.dart';

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
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载配置错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status View')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _configs.isEmpty
              ? const Center(
                child: Text(
                  '没有配置，\n点击右下角 + 添加',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                padding: const EdgeInsets.all(14),
                itemCount: _configs.length,
                itemBuilder: (context, index) {
                  final config = _configs[index];
                  return _buildStatusItem(config, index);
                },
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.blue.shade100,
      ),
      child: InkWell(
        onTap: () {
          // 点击查看详情或刷新状态的逻辑
          debugPrint('点击查看: ${config.name}');
        },
        onLongPress: () {
          _showOptionsDialog(config);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, size: 40),
            const SizedBox(height: 8),
            Text(
              config.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('等待获取...', style: TextStyle(color: Colors.grey.shade700)),
          ],
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
