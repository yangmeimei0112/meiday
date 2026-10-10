import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/glassmorphism.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/auth_state.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class MagicLinkSentScreen extends ConsumerStatefulWidget {
  final String email;

  const MagicLinkSentScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<MagicLinkSentScreen> createState() => _MagicLinkSentScreenState();
}

class _MagicLinkSentScreenState extends ConsumerState<MagicLinkSentScreen> {
  final _otpCtrl = TextEditingController();
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _secondsRemaining = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next is Authenticated) {
        if (mounted) {
          context.go(RouteConstants.calendar);
        }
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('驗證免密碼連結'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: GlassmorphismStyles.glassDecoration(
                context: context,
                borderRadius: 24,
                opacity: 0.9,
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '已發送驗證郵件',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '我們已將免密碼登入連結寄送至：\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Manual OTP code verification
                  Text(
                    '或在此輸入 6 位數字驗證碼：',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _otpCtrl,
                    labelText: '6 位數驗證碼',
                    hintText: '123456',
                    prefixIcon: Icons.pin_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final code = _otpCtrl.text.trim();
                      if (code.isNotEmpty) {
                        ref.read(authNotifierProvider.notifier).verifyOtp(widget.email, code);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('驗證並登入'),
                  ),
                  const SizedBox(height: 20),

                  // Resend countdown
                  Center(
                    child: _secondsRemaining > 0
                        ? Text(
                            '若未收到信件，可在 $_secondsRemaining 秒後重新發送',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () {
                              ref.read(authNotifierProvider.notifier).sendMagicLink(widget.email);
                              _startCountdown();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('重新發送驗證信'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
