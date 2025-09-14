// lib/pages/signin_page.dart
import 'package:flutter/material.dart';
import '../../state.dart';

class SignInPage extends StatefulWidget {
  final AppState state;
  const SignInPage({super.key, required this.state});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    _name.text = st.name ?? '';
    _phone.text = st.phone ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم الثلاثي'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                st.name  = _name.text.trim();
                st.phone = _phone.text.trim();
                await st.save();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
