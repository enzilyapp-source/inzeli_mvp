import 'dart:async';
import 'package:flutter/material.dart';
import '../api_room.dart';

class RoomTimerBanner extends StatefulWidget {
  final String code;
  final String? token;
  final bool dense; // لو تبين نسخة صغيرة
  const RoomTimerBanner({super.key, required this.code, this.token, this.dense = false});

  @override
  State<RoomTimerBanner> createState() => _RoomTimerBannerState();
}

class _RoomTimerBannerState extends State<RoomTimerBanner> {
  Timer? _ticker;
  int _remaining = 0;
  DateTime? _startedAt;
  int? _timerSec;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(); // أول تحميل
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final room = await ApiRoom.getRoomByCode(widget.code, token: widget.token);
      _timerSec  = (room['timerSec'] as num?)?.toInt();
      final s    = room['startedAt'] as String?;
      _startedAt = s != null ? DateTime.tryParse(s) : null;
    } catch (_) {
      // تجاهل أخطاء الشبكة لحين التحديث القادم
    } finally {
      setState(() => _loading = false);
      _tick(); // احسب بعد الجلب
    }
  }

  void _tick() {
    if (_startedAt == null || _timerSec == null) {
      setState(() => _remaining = 0);
      return;
    }
    final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
    final remain  = _timerSec! - elapsed;
    setState(() => _remaining = remain.clamp(0, 1 << 30));
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (_loading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [ SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) ],
      );
    }
    if (_timerSec == null || _startedAt == null) {
      // لا عدّاد بعد
      return const SizedBox.shrink();
    }
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, size: 18),
        const SizedBox(width: 6),
        Text(_fmt(_remaining), style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
      ],
    );
    return widget.dense ? child : Card(child: Padding(padding: const EdgeInsets.all(8), child: child));
  }
}
