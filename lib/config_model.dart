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
}
