import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config_model.dart';
import 'config_storage.dart';
import 'status_service.dart';
import 'dart:convert';
import 'dart:math' as math;

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

  // 添加控制器
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _jsonSyntaxController;
  late TextEditingController _stringFormatController;

  @override
  void initState() {
    super.initState();

    // 如果有初始配置（编辑模式），使用它
    // 如果是新建配置，则使用真正的空值
    if (widget.initialConfig != null) {
      // 编辑现有配置
      _config = widget.initialConfig!;
    } else {
      // 新建配置，使用真正的空值
      _config = StatusConfig(
        url: "",
        name: "",
        jsonSyntax: r"$.",
        stringFormat: "%s",
      );
    }

    // 初始化控制器
    _nameController = TextEditingController(text: _config.name);
    _urlController = TextEditingController(text: _config.url);
    _jsonSyntaxController = TextEditingController(text: _config.jsonSyntax);
    _stringFormatController = TextEditingController(text: _config.stringFormat);
  }

  @override
  void dispose() {
    // 释放控制器
    _nameController.dispose();
    _urlController.dispose();
    _jsonSyntaxController.dispose();
    _stringFormatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否是编辑模式
    final bool isEditMode = widget.initialConfig != null;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 添加模板选择按钮
              if (!isEditMode) // 仅在新建配置时显示
                _buildTemplateSelector(context),

              const SizedBox(height: 24),

              // 配置名称
              _buildTextField(
                label: '配置名称*',
                hint: isEditMode ? '我的配置' : '输入一个易于识别的名称',
                icon: Icons.label,
                controller: _nameController,
                validator:
                    (value) => value == null || value.isEmpty ? '请输入名称' : null,
                onSaved: (value) => _config = _config.copyWith(name: value!),
                disabled: isEditMode, // 编辑模式下不允许修改名称
              ),
              const SizedBox(height: 24),

              // URL输入
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    label: 'API地址*',
                    hint:
                        isEditMode
                            ? 'https://example.com/api'
                            : 'https://api.example.com/status',
                    icon: Icons.link,
                    controller: _urlController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return '请输入URL';
                      if (!value.startsWith('http')) return '需以http/https开头';
                      return null;
                    },
                    onSaved: (value) => _config = _config.copyWith(url: value!),
                  ),
                  const SizedBox(height: 8),
                  // 测试连接按钮
                  TextButton.icon(
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('测试连接'),
                    onPressed: _testApiConnection,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // JSON语法
              _buildTextField(
                label: 'JSON语法*',
                hint:
                    isEditMode
                        ? r'$.data.items'
                        : r'$.data.status 或 $.results[0].value',
                icon: Icons.code,
                controller: _jsonSyntaxController,
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
                hint: isEditMode ? 'Status: %s' : '状态: %s (%s 会被替换为API返回的值)',
                icon: Icons.format_quote,
                controller: _stringFormatController,
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
              if (!isEditMode)
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('清空所有输入'),
                  onPressed: () {
                    // 更新控制器为空值
                    _nameController.text = "";
                    _urlController.text = "";
                    _jsonSyntaxController.text = r"$.";
                    _stringFormatController.text = "%s";

                    // 设置配置对象为空
                    _config = StatusConfig(
                      url: "",
                      name: "",
                      jsonSyntax: r"$.",
                      stringFormat: "%s",
                    );

                    // 重置表单验证状态
                    if (_formKey.currentState != null) {
                      _formKey.currentState!.reset();
                    }

                    // 通知框架刷新
                    setState(() {});

                    // 显示提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已清空所有输入'),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
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
    required TextEditingController controller,
    required FormFieldSetter<String?> onSaved,
    FormFieldValidator<String?>? validator,
    bool disabled = false,
  }) {
    return TextFormField(
      enabled: !disabled,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
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

          // 保存成功，设置一个成功标志
          setState(() {
            _isSaving = false;
            // 延迟返回，让用户看到成功消息
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pop(context, true); // 返回true表示保存成功
              }
            });
          });

          return; // 提前返回，避免执行下面的代码
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

  // 构建模板选择器
  Widget _buildTemplateSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '开始方式',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 使用模板按钮
          Material(
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.shade50,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showTemplateDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '使用预定义模板',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '快速配置常用API',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 显示模板选择对话框
  void _showTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final templates = StatusConfig.getTemplates();
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text('选择模板'),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4, // 限制高度，避免过大
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // 先获取当前的BuildContext
                      final currentContext = context;

                      // 先关闭对话框
                      Navigator.pop(context);

                      // 然后更新状态和显示提示
                      setState(() {
                        _config = template.copyWith();
                        // 更新控制器的值
                        _nameController.text = template.name;
                        _urlController.text = template.url;
                        _jsonSyntaxController.text = template.jsonSyntax;
                        _stringFormatController.text = template.stringFormat;
                      });

                      // 显示提示
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text('已应用模板: ${template.name}'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.15),
                            radius: 24,
                            child: Text(
                              template.name.substring(0, 1),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  template.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('取消'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  // 测试API连接
  Future<void> _testApiConnection() async {
    // 直接从控制器获取URL
    final url = _urlController.text;
    final jsonSyntax = _jsonSyntaxController.text;

    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的URL地址'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            title: Text('测试连接中...'),
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
    );

    try {
      final result = await StatusService.testApiConnection(url);

      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      // 显示结果对话框
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      result['isSuccess'] ? Icons.check_circle : Icons.error,
                      color: result['isSuccess'] ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('测试结果'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result['message']}',
                        style: TextStyle(
                          color:
                              result['isSuccess']
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                        ),
                      ),
                      if (result['statusCode'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text('状态码: ${result['statusCode']}'),
                        ),
                      if (jsonSyntax.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildJsonPathResultText(
                            result['responseBody'],
                            jsonSyntax,
                          ),
                        ),
                      if (result['responseBody']?.isNotEmpty == true) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            '响应内容:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            '${result['responseBody']}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (result['isSuccess'])
                    TextButton(
                      child: const Text('我明白了'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  if (!result['isSuccess'])
                    TextButton(
                      child: const Text('关闭'),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      // 显示错误信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试过程中发生错误: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 构建JSON路径结果文本小部件
  Widget _buildJsonPathResultText(dynamic jsonData, String jsonPath) {
    try {
      if (jsonData == null || jsonData.toString().isEmpty) {
        return const Text(
          '解析结果: 无数据可解析',
          style: TextStyle(color: Colors.orange),
        );
      }

      // 确保jsonData是有效的JSON对象或数组
      dynamic parsedJson;
      if (jsonData is String) {
        try {
          parsedJson = jsonDecode(jsonData);
        } catch (e) {
          return Text(
            '解析结果: 无法解析JSON字符串 - ${e.toString().substring(0, math.min(50, e.toString().length))}',
            style: const TextStyle(color: Colors.red),
          );
        }
      } else {
        parsedJson = jsonData;
      }

      // 使用StatusService提取值
      final extractedValue = StatusService.extractValueFromJson(
        parsedJson,
        jsonPath,
      );

      if (extractedValue == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('解析结果: 未找到匹配值', style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 4),
            Text(
              '检查JSON语法是否正确: $jsonPath',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      } else {
        return Text(
          '解析结果: $extractedValue',
          style: const TextStyle(color: Colors.green),
        );
      }
    } catch (e) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '解析错误: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 4),
          const Text(
            '请检查JSON语法格式是否正确',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }
  }
}
