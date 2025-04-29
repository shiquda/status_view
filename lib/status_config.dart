import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config_model.dart';
import 'config_storage.dart';

class configPage extends StatelessWidget {
  final StatusConfig? initialConfig;

  const configPage({super.key, this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(initialConfig == null ? '添加配置' : '编辑配置'),
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.help),
          ),
        ],
      ),
      body: _ConfigForm(initialConfig: initialConfig),
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
  final StatusConfig? initialConfig;

  const _ConfigForm({this.initialConfig});

  @override
  State<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends State<_ConfigForm> {
  final _formKey = GlobalKey<FormState>();
  late StatusConfig _config;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 如果有初始配置，使用它，否则使用空配置
    _config = widget.initialConfig ?? StatusConfig.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 配置名称
              _buildTextField(
                label: '配置名称*',
                hint: '我的配置',
                icon: Icons.label,
                initialValue: _config.name,
                validator:
                    (value) => value == null || value.isEmpty ? '请输入名称' : null,
                onSaved: (value) => _config = _config.copyWith(name: value!),
                disabled: widget.initialConfig != null, // 编辑模式下不允许修改名称
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // 字符串格式
              _buildTextField(
                label: '字符串格式',
                hint: 'Status: %s',
                icon: Icons.format_quote,
                initialValue: _config.stringFormat,
                onSaved:
                    (value) => _config = _config.copyWith(stringFormat: value),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              ElevatedButton.icon(
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save, size: 20),
                label: Text(
                  _isSaving ? '保存中...' : '保存配置',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSaving ? null : _saveConfig,
              ),
              const SizedBox(height: 16),

              // 重置按钮
              if (widget.initialConfig == null)
                TextButton(
                  child: const Text('清空所有输入'),
                  onPressed:
                      () => setState(() {
                        _config = StatusConfig.empty();
                        _formKey.currentState?.reset();
                      }),
                ),
            ],
          ),
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
    bool disabled = false,
  }) {
    return TextFormField(
      enabled: !disabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      // 仅在编辑现有配置时提供初始值，否则为null
      initialValue: widget.initialConfig != null ? initialValue : null,
      validator: validator,
      onSaved: onSaved,
      inputFormatters:
          label.contains('URL')
              ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))] // 禁止URL输入空格
              : null,
    );
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      // 设置保存状态指示器
      setState(() {
        _isSaving = true;
      });

      // 保存表单数据到_config对象
      _formKey.currentState!.save();

      try {
        // 使用ConfigStorage保存配置
        final success = await ConfigStorage.addConfig(_config);

        if (!mounted) return; // 检查widget是否仍然挂载

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.initialConfig == null
                    ? '配置已创建: ${_config.name}'
                    : '配置已更新: ${_config.name}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          debugPrint('保存的配置: ${_config.toMap()}');

          // 返回主页
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('配置保存失败，请重试'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存时发生错误: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        // 恢复保存状态
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }
}
