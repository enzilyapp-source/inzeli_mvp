import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_base.dart';

/// Above Navigator so maintenance also covers open sheets and nested routes.
class OperationsGate extends StatefulWidget {
  final Widget child;
  final http.Client? client;
  const OperationsGate({super.key, required this.child, this.client});
  static void Function(List<dynamic>)? onHiddenGames;
  static List<dynamic> hiddenGameIds = [];
  @override
  State<OperationsGate> createState() => _OperationsGateState();
}

class _OperationsGateState extends State<OperationsGate>
    with WidgetsBindingObserver {
  final http.Client _client = http.Client();
  Timer? _timer;
  bool _maintenance = false;
  bool _checking = false;
  String _message = 'التطبيق تحت الصيانة، بنرجع لكم قريبًا';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_checking) return;
    _checking = true;
    try {
      final response = await (widget.client ?? _client)
          .get(Uri.parse('$apiBase/app-settings'))
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 || body['ok'] != true) return;
      final data = body['data'] as Map;
      OperationsGate.hiddenGameIds =
          List<dynamic>.from(data['hiddenGameIds'] ?? []);
      OperationsGate.onHiddenGames?.call(OperationsGate.hiddenGameIds);
      if (mounted) {
        setState(() {
          _maintenance = data['maintenanceEnabled'] == true;
          _message = (data['maintenanceMessage'] ?? _message).toString();
        });
      }
    } catch (_) {
      // Preserve the last known state during a temporary connection failure.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_maintenance)
            Positioned.fill(
                child: PopScope(
              canPop: false,
              child: Material(
                  color: const Color(0xFF223448),
                  child: SafeArea(
                      child: Center(
                          child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.construction_rounded,
                          size: 76, color: Color(0xFFE49A2C)),
                      const SizedBox(height: 24),
                      const Text('صيانة التطبيق',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(_message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة')),
                    ]),
                  )))),
            )),
        ],
      );
}
