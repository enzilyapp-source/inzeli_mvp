import 'package:flutter/material.dart';
import '../state.dart';
import '../api_username.dart';
import '../username_rules.dart';

/// Independent save flow: a failed claim never changes the cached handle or ID.
class UsernameSettingsTile extends StatelessWidget {
  final AppState app;
  const UsernameSettingsTile({super.key, required this.app});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: app,
        builder: (context, _) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alternate_email),
          title: Text(app.username == null
              ? 'احجز اسم مستخدم فريد'
              : '@${app.username}'),
          subtitle: const Text('تغييره يحافظ على حسابك ونتائجك'),
          trailing: TextButton(
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => _UsernameDialog(app: app)),
            child: Text(app.username == null ? 'حجز' : 'تغيير'),
          ),
        ),
      );
}

class _UsernameDialog extends StatefulWidget {
  final AppState app;
  const _UsernameDialog({required this.app});
  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.app.username ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit({bool checkOnly = false}) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = normalizedUsername(_username.text);
      if (checkOnly) {
        final result = await ApiUsernames.availability(value);
        if (mounted) {
          setState(() => _message =
              result['available'] == true || value == widget.app.username
                  ? '@$value متاح لك'
                  : 'اسم المستخدم محجوز، اختَر اسمًا آخر');
        }
      } else {
        await widget.app.claimUsername(value);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = e is UsernameException
            ? e.toString()
            : 'تعذر الاتصال، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('اسم المستخدم الفريد'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'حروف إنجليزية وأرقام وشرطة سفلية. الأحرف الكبيرة والصغيرة تحجز نفس الاسم.'),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _username,
                          enabled: !_busy,
                          maxLength: 20,
                          textDirection: TextDirection.ltr,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                              labelText: 'اسم المستخدم', prefixText: '@'),
                          validator: usernameValidationError,
                          onChanged: (_) => setState(() => _message = null)),
                      if (_message != null) Text(_message!),
                      if (_busy) const LinearProgressIndicator(),
                      TextButton(
                          onPressed:
                              _busy ? null : () => _submit(checkOnly: true),
                          child: const Text('تحقق من التوفر')),
                    ]))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: _busy ? null : () => _submit(),
              child: const Text('حفظ اسم المستخدم')),
        ],
      );
}
