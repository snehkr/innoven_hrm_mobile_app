import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/api_service.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kOrange  = Color(0xFFF97316);
const _kBg      = Color(0xFFF1F4F9);

class OtpVerifyScreen extends StatefulWidget {
  final String ticketId;
  final String? maskedEmail;
  const OtpVerifyScreen({super.key, required this.ticketId, this.maskedEmail});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _otpController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading    = false;
  bool _isResending  = false;
  bool _isVerified   = false;
  int  _timerSeconds = 30;
  Timer? _timer;

  late AnimationController _shakeController;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 8)
      .chain(CurveTween(curve: Curves.elasticIn))
      .animate(_shakeController);
    _startTimer();
  }

  void _startTimer() {
    _timerSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 0) { t.cancel(); return; }
      if (mounted) setState(() => _timerSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _otpController.dispose();
    for (final c in _pinControllers) c.dispose();
    for (final f in _pinFocusNodes) f.dispose();
    super.dispose();
  }

  String get _currentOtp =>
      _pinControllers.map((c) => c.text).join();

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final res = await _apiService.post('/otp/send', {'request_id': widget.ticketId});
      if (res.statusCode == 200) {
        Fluttertoast.showToast(msg: '✓ OTP Resent', backgroundColor: const Color(0xFF22C55E));
        _startTimer();
      } else {
        Fluttertoast.showToast(msg: 'Failed to resend OTP', backgroundColor: const Color(0xFFEF4444));
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Network error', backgroundColor: const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _currentOtp;
    if (otp.length != 4) {
      _shakeController.forward(from: 0);
      Fluttertoast.showToast(msg: 'Enter all 4 digits', backgroundColor: const Color(0xFFEF4444));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.post('/otp/verify', {
        'request_id': widget.ticketId, 'otp': otp,
      });
      if (res.statusCode == 200) {
        setState(() => _isVerified = true);
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) context.go('/engineer/proof/${widget.ticketId}');
      } else {
        _shakeController.forward(from: 0);
        for (final c in _pinControllers) c.clear();
        _pinFocusNodes[0].requestFocus();
        Fluttertoast.showToast(msg: 'Invalid or expired OTP', backgroundColor: const Color(0xFFEF4444));
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Verification failed', backgroundColor: const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/engineer'),
        ),
        title: const Text('Verify Customer OTP',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: isLandscape ? _buildLandscape() : _buildPortrait(),
    );
  }

  Widget _buildPortrait() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          _buildHeroCard(),
          const SizedBox(height: 32),
          _buildPinRow(),
          const SizedBox(height: 20),
          _buildResendRow(),
          const SizedBox(height: 28),
          _buildVerifyButton(),
        ]),
      ),
    );
  }

  Widget _buildLandscape() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: _buildHeroCard()),
          const SizedBox(width: 24),
          Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildPinRow(),
            const SizedBox(height: 16),
            _buildResendRow(),
            const SizedBox(height: 20),
            _buildVerifyButton(),
          ])),
        ]),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isVerified
              ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
              : [_kPrimary, const Color(0xFF1565C0)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: (_isVerified ? const Color(0xFF22C55E) : _kPrimary).withOpacity(0.3),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isVerified
              ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44, key: ValueKey('done'))
              : const Icon(Icons.lock_open_rounded, color: Colors.white, size: 44, key: ValueKey('lock')),
        ),
        const SizedBox(height: 14),
        Text(
          _isVerified ? 'Verified! ✓' : 'OTP Verification',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _isVerified
              ? 'Proceeding to upload proof...'
              : widget.maskedEmail != null
                  ? 'OTP sent to customer at:\n${widget.maskedEmail}'
                  : 'Enter the 4-digit OTP provided\nby the customer.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
      ]),
    );
  }

  Widget _buildPinRow() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value * ((_shakeController.value * 10).toInt().isEven ? 1 : -1), 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) => _PinBox(
          controller: _pinControllers[i],
          focusNode: _pinFocusNodes[i],
          isVerified: _isVerified,
          onChanged: (val) {
            if (val.length == 1 && i < 3) _pinFocusNodes[i + 1].requestFocus();
            if (val.isEmpty && i > 0) _pinFocusNodes[i - 1].requestFocus();
            if (_currentOtp.length == 4) _verifyOtp();
          },
        )),
      ),
    );
  }

  Widget _buildResendRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Didn't receive code? ",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      _isResending
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
          : TextButton(
              onPressed: _timerSeconds == 0 ? _resendOtp : null,
              child: Text(
                _timerSeconds > 0 ? 'Resend in ${_timerSeconds}s' : 'Resend OTP',
                style: TextStyle(
                  color: _timerSeconds == 0 ? _kPrimary : Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    ]);
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (_isLoading || _isVerified) ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 4,
          shadowColor: _kOrange.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_isVerified ? Icons.check_rounded : Icons.verified_user_rounded, size: 20),
                const SizedBox(width: 10),
                Text(_isVerified ? 'Verified!' : 'Verify OTP',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
      ),
    );
  }
}

// ── PIN Input Box ─────────────────────────────────────────────────────────────
class _PinBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isVerified;
  final ValueChanged<String> onChanged;

  const _PinBox({
    required this.controller,
    required this.focusNode,
    required this.isVerified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 68,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.bold,
          color: isVerified ? const Color(0xFF22C55E) : const Color(0xFF0D47A1),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isVerified ? const Color(0xFF22C55E).withOpacity(0.08) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kOrange, width: 2.5),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
