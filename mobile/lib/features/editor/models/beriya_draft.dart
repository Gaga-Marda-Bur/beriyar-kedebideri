import 'dart:convert';

class BeriyaDraft {
  final String id;
  final String title;
  final String content;
  final double fontSize;
  final String alignment; // 'left', 'center', 'right'
  final String theme; // 'dark_forest', 'cream', 'golden', 'paper'
  final DateTime updatedAt;

  const BeriyaDraft({
    required this.id,
    required this.title,
    required this.content,
    this.fontSize = 22.0,
    this.alignment = 'left',
    this.theme = 'dark_forest',
    required this.updatedAt,
  });

  factory BeriyaDraft.initial() {
    return BeriyaDraft(
      id: 'default_draft',
      title: '',
      content: '',
      fontSize: 22.0,
      alignment: 'left',
      theme: 'dark_forest',
      updatedAt: DateTime.now(),
    );
  }

  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  BeriyaDraft copyWith({
    String? id,
    String? title,
    String? content,
    double? fontSize,
    String? alignment,
    String? theme,
    DateTime? updatedAt,
  }) {
    return BeriyaDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      fontSize: fontSize ?? this.fontSize,
      alignment: alignment ?? this.alignment,
      theme: theme ?? this.theme,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'fontSize': fontSize,
      'alignment': alignment,
      'theme': theme,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BeriyaDraft.fromMap(Map<String, dynamic> map) {
    return BeriyaDraft(
      id: map['id']?.toString() ?? 'default_draft',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 22.0,
      alignment: map['alignment']?.toString() ?? 'left',
      theme: map['theme']?.toString() ?? 'dark_forest',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BeriyaDraft.fromJson(String source) =>
      BeriyaDraft.fromMap(json.decode(source) as Map<String, dynamic>);
}
