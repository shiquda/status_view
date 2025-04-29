class StatusConfig {
  final String url;
  final String name;
  final String jsonSyntax;
  final String stringFormat;

  StatusConfig({
    required this.url,
    required this.name,
    required this.jsonSyntax,
    required this.stringFormat,
  });

  // 创建一个空的配置，用于新建配置时使用
  factory StatusConfig.empty() =>
      StatusConfig(url: "", name: "", jsonSyntax: r"$.", stringFormat: "%s");

  // 保留默认示例配置，但不用于初始化表单
  factory StatusConfig.defaults() => StatusConfig(
    url: "https://example.com/status",
    name: "默认状态",
    jsonSyntax: r"$.data.status",
    stringFormat: "status: %s",
  );

  factory StatusConfig.fromMap(Map<String, dynamic> map) => StatusConfig(
    url: map['url'] ?? 'https://example.com/status',
    name: map['name'] ?? '默认状态',
    jsonSyntax: map['jsonSyntax'] ?? r"$.data.status",
    stringFormat: map['stringFormat'] ?? "status: %s",
  );

  Map<String, dynamic> toMap() => {
    "url": url,
    "name": name,
    "jsonSyntax": jsonSyntax,
    "stringFormat": stringFormat,
  };

  StatusConfig copyWith({
    String? url,
    String? name,
    String? jsonSyntax,
    String? stringFormat,
  }) => StatusConfig(
    url: url ?? this.url,
    name: name ?? this.name,
    jsonSyntax: jsonSyntax ?? this.jsonSyntax,
    stringFormat: stringFormat ?? this.stringFormat,
  );

  // 用于对象比较和集合操作
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          name == other.name &&
          jsonSyntax == other.jsonSyntax &&
          stringFormat == other.stringFormat;

  @override
  int get hashCode =>
      url.hashCode ^
      name.hashCode ^
      jsonSyntax.hashCode ^
      stringFormat.hashCode;

  // 返回预定义的配置模板列表
  static List<StatusConfig> getTemplates() {
    return [
      // Github仓库星数
      StatusConfig(
        url: "https://api.github.com/repos/flutter/flutter",
        name: "Flutter Github 星数",
        jsonSyntax: r"$.stargazers_count",
        stringFormat: "⭐ %s",
      ),

      StatusConfig(
        url: "https://international.v1.hitokoto.cn/",
        name: "一言",
        jsonSyntax: r"$.hitokoto",
        stringFormat: "%s",
      ),

      // 公共测试API
      StatusConfig(
        url: "https://jsonplaceholder.typicode.com/todos/1",
        name: "待办事项",
        jsonSyntax: r"$.title",
        stringFormat: "📋 %s",
      ),

      // 随机笑话API
      StatusConfig(
        url: "https://official-joke-api.appspot.com/random_joke",
        name: "每日笑话",
        jsonSyntax: r"$.setup",
        stringFormat: "😄 %s",
      ),
    ];
  }
}
