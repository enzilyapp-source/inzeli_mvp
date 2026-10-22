/// Match server common/username.ts; the database remains the uniqueness authority.
String normalizedUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

String? usernameValidationError(String? value) {
  final username = normalizedUsername(value ?? '');
  if (username.isEmpty) return 'اسم المستخدم مطلوب';
  if (!RegExp(r'^[a-z][a-z0-9_]{2,19}$').hasMatch(username)) {
    return '٣–٢٠ حرفًا، يبدأ بحرف إنجليزي، ويسمح بالأرقام و _';
  }
  if (const {
    'admin',
    'administrator',
    'support',
    'help',
    'enzily',
    'enzeli',
    'inzeli',
    'official',
    'system',
    'moderator',
    'root'
  }.contains(username)) {
    return 'هذا الاسم محجوز، اختَر اسمًا آخر';
  }
  return null;
}
