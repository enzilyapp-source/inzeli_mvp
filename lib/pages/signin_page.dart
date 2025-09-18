import 'package:flutter/material.dart';
import '../state.dart';
import '../api_auth.dart';

class SignInPage extends StatefulWidget {
  final AppState app;
  const SignInPage({super.key, required this.app});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _busy = false;
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _name  = TextEditingController();

  @override
  void dispose() { _email.dispose(); _pass.dispose(); _name.dispose(); super.dispose(); }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      ApiResponse<Map<String, dynamic>> r;
      if (_isLogin) {
        r = await login(email: _email.text.trim(), password: _pass.text);
      } else {
        r = await register(email: _email.text.trim(), password: _pass.text, displayName: _name.text.trim());
      }

      // debug prints
      // ignore: avoid_print
      print('AUTH ok=${r.ok} msg=${r.message} data=${r.data}');

      if (!r.ok) { _msg(r.message); return; }
      final token = r.data!['token'] as String;
      final user  = r.data!['user']  as Map<String, dynamic>;

      await widget.app.setAuthFromBackend(token: token, user: user);
      _msg(_isLogin ? 'تم تسجيل الدخول ✅' : 'تم إنشاء الحساب 🎉');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _msg(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'تسجيل دخول' : 'تسجيل حساب')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sports_esports, size: 72),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'الإيميل'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الإيميل مطلوب';
                    if (!v.contains('@')) return 'أدخل إيميل صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'كلمة السر'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? '٦ أحرف على الأقل' : null,
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isLogin ? Icons.login : Icons.person_add),
                    label: Text(_isLogin ? 'دخول' : 'تسجيل'),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'ما عندك حساب؟ إنشاء حساب' : 'عندك حساب؟ تسجيل دخول'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
