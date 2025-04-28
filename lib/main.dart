import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'config_model.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Status View',
      home: const statusViewPage(),
      theme: ThemeData(
        colorScheme: AppTheme.lightScheme,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class statusViewPage extends StatelessWidget {
  const statusViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status View')),
      body: GridView.count(
        crossAxisCount: 2,
        children: List.generate(
          10,
          (index) => Container(
            margin: EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.blue,
            ),
            child: Center(child: Text('Item $index')),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint("添加组件");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const configPage()),
          );
        },
        backgroundColor: AppTheme.lightScheme.surface,
        tooltip: "添加Status",
        child: Icon(Icons.add, color: AppTheme.lightScheme.onSurface),
      ),
    );
  }
}

class configPage extends StatelessWidget {
  const configPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('状态配置'),
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.help),
          ),
        ],
      ),
      body: _ConfigForm(),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('配置说明'),
            content: const Text(
              '请填写所有必填字段（标有*）\n'
              'URL需以http/https开头\n'
              'JSON语法建议使用JSONPath格式',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
    );
  }
}

class _ConfigForm extends StatefulWidget {
  @override
  State<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends State<_ConfigForm> {
  final _formKey = GlobalKey<FormState>();
  var _config = StatusConfig.defaults(); // 使用你的默认配置
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // URL输入
            _buildTextField(
              label: 'API地址*',
              hint: 'https://example.com/api',
              icon: Icons.link,
              initialValue: _config.url,
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入URL';
                if (!value.startsWith('http')) return '需以http/https开头';
                return null;
              },
              onSaved: (value) => _config = _config.copyWith(url: value!),
            ),
            const SizedBox(height: 40),
            // 配置名称
            _buildTextField(
              label: '配置名称*',
              hint: '我的配置',
              icon: Icons.label,
              initialValue: _config.name,
              validator:
                  (value) => value == null || value.isEmpty ? '请输入名称' : null,
              onSaved: (value) => _config = _config.copyWith(name: value!),
            ),
            const SizedBox(height: 40),
            // JSON语法
            _buildTextField(
              label: 'JSON语法*',
              hint: r'$.data.items',
              icon: Icons.code,
              initialValue: _config.jsonSyntax,
              validator:
                  (value) =>
                      value == null || value.isEmpty ? '请输入JSON语法' : null,
              onSaved:
                  (value) => _config = _config.copyWith(jsonSyntax: value!),
            ),
            const SizedBox(height: 40),
            // 字符串格式
            _buildTextField(
              label: '字符串格式',
              hint: 'Status: %s',
              icon: Icons.format_quote,
              initialValue: _config.stringFormat,
              onSaved:
                  (value) => _config = _config.copyWith(stringFormat: value),
            ),
            const SizedBox(height: 40),
            // 保存按钮
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 20),
              label: const Text('保存配置', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saveConfig,
            ),
            const SizedBox(height: 20),
            // 重置按钮
            TextButton(
              child: const Text('恢复默认设置'),
              onPressed:
                  () => setState(() {
                    _config = StatusConfig.defaults();
                    _formKey.currentState?.reset();
                  }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required String? initialValue,
    required FormFieldSetter<String?> onSaved,
    FormFieldValidator<String?>? validator,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      initialValue: initialValue,
      validator: validator,
      onSaved: onSaved,
      inputFormatters:
          label.contains('URL')
              ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))] // 禁止URL输入空格
              : null,
    );
  }

  void _saveConfig() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // 这里可以添加保存到本地或服务器的逻辑
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配置已保存: ${_config.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
      debugPrint('保存的配置: ${_config.toMap()}');

      // 返回主页
      Navigator.pop(context);
    }
  }
}
