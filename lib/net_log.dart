void netLog(String label, Object data) {
  // اطبعي في الكونسول
  // تقدرِين تشيلينه لاحقًا
  // (split to avoid long single lines)
  final s = data.toString();
  const chunk = 800;
  for (int i = 0; i < s.length; i += chunk) {
    final part = s.substring(i, (i + chunk < s.length) ? i + chunk : s.length);
    // // ignore: avoid_print
    print('[$label] $part');
  }
}
//lib/net_log.dart