// lib/pages/signin_page.dart
import 'package:flutter/material.dart';
import '../widgets/app_snackbar.dart';
import '../state.dart';
import '../api_auth.dart';
import '../main.dart' show AuthGate; // to re-enter the gate after success
import '../widgets/primary_pill_button.dart';

class SignInPage extends StatefulWidget {
  final AppState app;
  const SignInPage({super.key, required this.app});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  static const List<_DialingCountry> _dialingCountries = [
    _DialingCountry(nameAr: 'الكويت', dialCode: '+965'),
    _DialingCountry(nameAr: 'السعودية', dialCode: '+966'),
    _DialingCountry(nameAr: 'الإمارات', dialCode: '+971'),
    _DialingCountry(nameAr: 'قطر', dialCode: '+974'),
    _DialingCountry(nameAr: 'البحرين', dialCode: '+973'),
    _DialingCountry(nameAr: 'عُمان', dialCode: '+968'),
  ];

  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _busy = false;
  String _dialCode = '+965';

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  DateTime? _birthDate;

  bool _awaitingOtp = false;
  String? _otpRequestId;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _msg(String m, {bool error = false, bool success = false}) {
    if (!mounted) return;
    showAppSnack(context, m, error: error, success: success);
  }

  void _resetOtpState() {
    _awaitingOtp = false;
    _otpRequestId = null;
    _otp.clear();
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  String _phoneForApi() {
    final raw = _phone.text.trim();
    if (raw.isEmpty) return '';

    final compact = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (compact.startsWith('+')) return compact;
    if (compact.startsWith('00')) return '+${compact.substring(2)}';

    final digits = _digitsOnly(compact);
    if (digits.isEmpty) return '';

    final codeDigits = _digitsOnly(_dialCode);
    if (digits.startsWith(codeDigits)) {
      return '+$digits';
    }
    return '$_dialCode$digits';
  }

  Future<void> _completeAuth(Map<String, dynamic> data,
      {required bool loginFlow}) async {
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token == null || user == null) {
      _msg('استجابة تسجيل الحساب غير مكتملة', error: true);
      return;
    }

    await widget.app.setAuthFromBackend(token: token, user: user);

    _msg(loginFlow ? 'تم تسجيل الدخول ✅' : 'تم إنشاء الحساب 🎉', success: true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  Future<void> _requestOtp({bool resend = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      _msg('تاريخ الميلاد مطلوب', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await requestRegisterOtp(
        email: _email.text.trim(),
        password: _pass.text,
        displayName: _name.text.trim(),
        phone: _phoneForApi(),
        birthDate: _birthDate!.toIso8601String(),
      );

      if (!r.ok) {
        _msg(r.message, error: true);
        return;
      }

      final data = r.data ?? <String, dynamic>{};

      // test/review account bypass can return token+user directly
      if (data['token'] is String && data['user'] is Map<String, dynamic>) {
        await _completeAuth(data, loginFlow: false);
        return;
      }

      final requestId = data['requestId']?.toString();
      if (data['otpRequired'] == true &&
          requestId != null &&
          requestId.isNotEmpty) {
        setState(() {
          _awaitingOtp = true;
          _otpRequestId = requestId;
        });

        if (resend) {
          _msg('تم إعادة إرسال رمز التحقق', success: true);
        } else {
          _msg('تم إرسال رمز التحقق إلى رقم الجوال', success: true);
        }
        return;
      }

      _msg('تعذر بدء تحقق OTP', error: true);
    } catch (e) {
      _msg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtpAndRegister() async {
    final code = _otp.text.trim();
    if (_otpRequestId == null || _otpRequestId!.isEmpty) {
      _msg('طلب OTP غير موجود، أعد إرسال الرمز', error: true);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _msg('أدخل رمز مكوّن من 6 أرقام', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await verifyRegisterOtp(requestId: _otpRequestId!, code: code);
      if (!r.ok) {
        _msg(r.message, error: true);
        return;
      }

      final data = r.data ?? <String, dynamic>{};
      await _completeAuth(data, loginFlow: false);
    } catch (e) {
      _msg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isLogin) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _busy = true);
      try {
        final r = await login(
          email: _email.text.trim(),
          password: _pass.text,
        );

        if (!r.ok) {
          _msg(r.message, error: true);
          return;
        }

        await _completeAuth(r.data ?? <String, dynamic>{}, loginFlow: true);
      } catch (e) {
        _msg(e.toString(), error: true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Register flow
    if (_awaitingOtp) {
      await _verifyOtpAndRegister();
    } else {
      await _requestOtp();
    }
  }

  void _toggleAuthMode() {
    if (_busy) return;
    setState(() {
      _isLogin = !_isLogin;
      _resetOtpState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockIdentityFields = !_isLogin && _awaitingOtp;

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
            final minHeight = (constraints.maxHeight - bottomInset)
                .clamp(0.0, double.infinity);

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
                          Image.asset(
                            'lib/assets/enzeli_logo.png',
                            width: 96,
                            height: 96,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            readOnly: lockIdentityFields,
                            decoration:
                                const InputDecoration(labelText: 'الإيميل'),
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
                            readOnly: lockIdentityFields,
                            decoration:
                                const InputDecoration(labelText: 'كلمة السر'),
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            validator: (v) => (v == null || v.length < 6)
                                ? '٦ أحرف على الأقل'
                                : null,
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _name,
                              readOnly: lockIdentityFields,
                              decoration:
                                  const InputDecoration(labelText: 'الاسم'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'الاسم مطلوب'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 148,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _dialCode,
                                    decoration: const InputDecoration(
                                      labelText: 'الدولة',
                                    ),
                                    isExpanded: true,
                                    onChanged: lockIdentityFields
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() => _dialCode = v);
                                          },
                                    items: _dialingCountries
                                        .map(
                                          (c) => DropdownMenuItem<String>(
                                            value: c.dialCode,
                                            child: Text(
                                                '${c.nameAr} (${c.dialCode})'),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phone,
                                    readOnly: lockIdentityFields,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم الجوال',
                                    ),
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [
                                      AutofillHints.telephoneNumber
                                    ],
                                    validator: (v) {
                                      final digits =
                                          _digitsOnly(v?.trim() ?? '');
                                      if (digits.isEmpty) {
                                        return 'رقم الجوال مطلوب';
                                      }

                                      if (_dialCode == '+965') {
                                        final isKuwaitLocal =
                                            digits.length == 8;
                                        final isKuwaitIntl =
                                            digits.length == 11 &&
                                                digits.startsWith('965');
                                        if (!isKuwaitLocal && !isKuwaitIntl) {
                                          return 'رقم كويتي غير صحيح';
                                        }
                                        return null;
                                      }

                                      if (digits.length < 7 ||
                                          digits.length > 12) {
                                        return 'رقم الجوال غير صحيح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _BirthDatePicker(
                              label: 'تاريخ الميلاد',
                              value: _birthDate,
                              enabled: !lockIdentityFields,
                              onChanged: (d) => setState(() => _birthDate = d),
                            ),
                            if (_awaitingOtp) ...[
                              const SizedBox(height: 14),
                              Text(
                                'تم إرسال رمز التحقق إلى ${_phoneForApi()}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _otp,
                                decoration: const InputDecoration(
                                    labelText: 'رمز التحقق (OTP)'),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _requestOtp(resend: true),
                                child: const Text(
                                  'إعادة إرسال الرمز',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          PrimaryPillButton(
                            label: _isLogin
                                ? 'دخول'
                                : (_awaitingOtp
                                    ? 'تأكيد الرمز'
                                    : 'إرسال رمز التحقق'),
                            onPressed: _busy ? null : _submit,
                            icon: _isLogin
                                ? Icons.login
                                : (_awaitingOtp
                                    ? Icons.verified_user
                                    : Icons.sms_outlined),
                            loading: _busy,
                          ),
                          TextButton(
                            onPressed: _busy ? null : _toggleAuthMode,
                            child: Text(
                              _isLogin
                                  ? 'ما عندك حساب؟ إنشاء حساب'
                                  : 'عندك حساب؟ تسجيل دخول',
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

/// بسيط: حقل يفتح DatePicker لاختيار سنة/شهر/يوم
class _BirthDatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  const _BirthDatePicker({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    if (!enabled) return;
    final now = DateTime.now();
    final initial = value ?? DateTime(now.year - 18, 1, 1);
    final first = DateTime(1900, 1, 1);
    final last = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: label,
      locale: const Locale('ar'),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? ''
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.65,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(display),
              const Icon(Icons.calendar_today, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialingCountry {
  final String nameAr;
  final String dialCode;

  const _DialingCountry({
    required this.nameAr,
    required this.dialCode,
  });
}
//pages/signin_page.dart
