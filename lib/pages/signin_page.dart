// lib/pages/signin_page.dart
import 'package:flutter/material.dart';
import '../state.dart';
import '../api_auth.dart';
import '../main.dart' show AuthGate; // ✅ to re-enter the gate after success
import '../widgets/primary_pill_button.dart';

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
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    // Close keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      ApiResponse<Map<String, dynamic>> r;
      if (_isLogin) {
        r = await login(email: _email.text.trim(), password: _pass.text);
      } else {
        r = await register(
          email: _email.text.trim(),
          password: _pass.text,
          displayName: _name.text.trim(),
        );
      }

      if (!r.ok) {
        _msg(r.message);
        return;
      }

      final token = r.data!['token'] as String;
      final user  = r.data!['user']  as Map<String, dynamic>;
      await widget.app.setAuthFromBackend(token: token, user: user);

      _msg(_isLogin ? 'تم تسجيل الدخول ✅' : 'تم إنشاء الحساب 🎉');

      if (!mounted) return;

      // ✅ Re-enter the gate so the app shows HomePage immediately
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
      );
    } catch (e) {
      _msg(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل دخول' : 'تسجيل حساب'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF232E4A), Color(0xFF34677A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final minHeight = (constraints.maxHeight - bottomInset).clamp(0.0, double.infinity);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_esports, size: 72, color: Colors.white),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(labelText: 'الإيميل'),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'الإيميل مطلوب';
                              if (!s.contains('@')) return 'أدخل إيميل صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          TextFormField(
                            controller: _pass,
                            decoration: const InputDecoration(labelText: 'كلمة السر'),
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) =>
                                (v == null || v.length < 6) ? '٦ أحرف على الأقل' : null,
                          ),

                          if (!_isLogin) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(labelText: 'الاسم'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                            ),
                          ],

                          const SizedBox(height: 16),

                          PrimaryPillButton(
                            label: _isLogin ? 'دخول' : 'تسجيل',
                            onPressed: _busy ? null : _submit,
                            icon: _isLogin ? Icons.login : Icons.person_add,
                            loading: _busy,
                          ),

                          TextButton(
                            onPressed: _busy ? null : () => setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin ? 'ما عندك حساب؟ إنشاء حساب' : 'عندك حساب؟ تسجيل دخول',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
//pages/signin_page.dart
