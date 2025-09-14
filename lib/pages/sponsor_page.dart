// lib/pages/sponsor_page.dart
import 'package:flutter/material.dart';
import '../state.dart';

class SponsorPage extends StatefulWidget {
  final AppState app;
  const SponsorPage({super.key, required this.app});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'ادخل كود السبونسر',
              hintText: 'مثال: SP-KOT6-AUG',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              app.setSponsorCode(_code.text.trim().isEmpty ? null : _code.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ الكود')),
              );
            },
            child: const Text('تفعيل'),
          ),
          const SizedBox(height: 12),
          if (app.activeSponsorCode != null)
            Text('الكود الفعّال: ${app.activeSponsorCode!}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
