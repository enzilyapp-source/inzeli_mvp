// lib/pages/signin_page.dart
import 'package:flutter/cupertino.dart';
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
        final channel = data['deliveryChannel']?.toString().toLowerCase();
        final channelLabel = channel == 'whatsapp' ? 'واتساب' : 'رسالة نصية';
        setState(() {
          _awaitingOtp = true;
          _otpRequestId = requestId;
        });

        if (resend) {
          _msg('تم إعادة إرسال رمز التحقق عبر $channelLabel',
              success: true);
        } else {
          _msg('تم إرسال رمز التحقق عبر $channelLabel', success: true);
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

  Future<void> _openForgotPassword() async {
    if (_busy) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ForgotPasswordSheet(
        initialEmail: _email.text.trim(),
        onCompleted: (data) async {
          Navigator.of(ctx).pop();
          await _completeAuth(data, loginFlow: true);
        },
      ),
    );
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
                            child: Text.rich(
                              TextSpan(
                                text:
                                    _isLogin ? 'ما عندك حساب؟ ' : 'عندك حساب؟ ',
                                style: const TextStyle(color: Colors.white),
                                children: [
                                  TextSpan(
                                    text:
                                        _isLogin ? 'إنشاء حساب' : 'تسجيل دخول',
                                    style: const TextStyle(
                                      color: Color(0xFFE7A73B),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isLogin)
                            TextButton(
                              onPressed: _busy ? null : _openForgotPassword,
                              child: const Text(
                                'نسيت كلمة السر؟',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
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

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(Map<String, dynamic> data) onCompleted;

  const _ForgotPasswordSheet({
    required this.initialEmail,
    required this.onCompleted,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _requestId;
  String? _phoneHint;

  bool get _awaitingOtp => _requestId != null && _requestId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _msg(String m, {bool error = false, bool success = false}) {
    if (!mounted) return;
    showAppSnack(context, m, error: error, success: success);
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final r = await requestPasswordResetOtp(email: _email.text.trim());
      if (!r.ok) {
        _msg(r.message, error: true);
        return;
      }

      final data = r.data ?? <String, dynamic>{};
      final requestId = data['requestId']?.toString();
      if (requestId == null || requestId.isEmpty) {
        _msg('تعذر بدء استرجاع كلمة السر', error: true);
        return;
      }

      setState(() {
        _requestId = requestId;
        _phoneHint = data['phoneHint']?.toString();
      });
      final target = (_phoneHint == null || _phoneHint!.isEmpty)
          ? 'رقم جوالك'
          : 'رقمك $_phoneHint';
      _msg('أرسلنا رمز التحقق إلى $target', success: true);
    } catch (e) {
      _msg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final requestId = _requestId;
    if (requestId == null || requestId.isEmpty) {
      _msg('طلب الاسترجاع غير موجود، أعد إرسال الرمز', error: true);
      return;
    }
    if (_password.text != _confirm.text) {
      _msg('كلمتا السر غير متطابقتين', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await resetPasswordWithOtp(
        requestId: requestId,
        code: _otp.text.trim(),
        password: _password.text,
      );
      if (!r.ok) {
        _msg(r.message, error: true);
        return;
      }

      _msg('تم تغيير كلمة السر', success: true);
      await widget.onCompleted(r.data ?? <String, dynamic>{});
    } catch (e) {
      _msg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'استرجاع كلمة السر',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: !_awaitingOtp && !_busy,
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
                if (_awaitingOtp) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otp,
                    decoration: const InputDecoration(labelText: 'رمز التحقق'),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (v) =>
                        RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'أدخل رمز مكوّن من 6 أرقام',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _password,
                    decoration:
                        const InputDecoration(labelText: 'كلمة السر الجديدة'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) =>
                        (v == null || v.length < 6) ? '٦ أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _confirm,
                    decoration:
                        const InputDecoration(labelText: 'تأكيد كلمة السر'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) =>
                        (v == null || v.length < 6) ? '٦ أحرف على الأقل' : null,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _requestId = null;
                                _phoneHint = null;
                                _otp.clear();
                                _password.clear();
                                _confirm.clear();
                              });
                            },
                      child: const Text('تغيير الإيميل'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                PrimaryPillButton(
                  label: _awaitingOtp ? 'تغيير كلمة السر' : 'إرسال الرمز',
                  onPressed: _busy
                      ? null
                      : (_awaitingOtp ? _resetPassword : _requestOtp),
                  icon: _awaitingOtp ? Icons.lock_reset : Icons.sms_outlined,
                  loading: _busy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// حقل تاريخ ميلاد بأسلوب أسهل (قائمة/عجلة) بدل تقويم كامل.
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

    DateTime temp = initial;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1F3556),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 320,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              onChanged(temp);
                              Navigator.pop(sheetCtx);
                            },
                            child: const Text(
                              'تم',
                              style: TextStyle(
                                color: Color(0xFFE7A73B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x3FFFFFFF)),
                    Expanded(
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          brightness: Brightness.dark,
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: initial,
                          minimumDate: first,
                          maximumDate: last,
                          onDateTimeChanged: (d) => temp = d,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
