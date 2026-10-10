import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/glassmorphism.dart';
import '../../../../core/constants/route_constants.dart';
import '../../domain/entities/auth_state.dart';
import '../dialogs/conflict_resolution_dialog.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class AuthPortalScreen extends ConsumerStatefulWidget {
  const AuthPortalScreen({super.key});

  @override
  ConsumerState<AuthPortalScreen> createState() => _AuthPortalScreenState();
}

class _AuthPortalScreenState extends ConsumerState<AuthPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();

  final _signUpNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();

  final _magicEmailCtrl = TextEditingController();

  bool _isHandlingConflict = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _magicEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) async {
      if (next is Authenticated) {
        if (mounted) {
          context.go(RouteConstants.calendar);
        }
      } else if (next is AuthMigrationRequired && !_isHandlingConflict) {
        _isHandlingConflict = true;
        final mode = await ConflictResolutionDialog.show(context);
        _isHandlingConflict = false;
        if (!mounted) return;
        if (mode != null) {
          await ref.read(authNotifierProvider.notifier).resolveMigrationConflict(mode);
        } else {
          await ref.read(authNotifierProvider.notifier).continueAsGuest();
        }
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    final isLoading = authState is AuthLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                    // Brand Logo & Title
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ChronoHub',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '智慧行事曆與時間中樞',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error Alert Banner
                    if (authState is AuthError) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.failure.message,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tab Switcher
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(text: '登入'),
                          Tab(text: '註冊'),
                          Tab(text: '免密碼'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab View Forms
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSignInTab(isLoading),
                          _buildSignUpTab(isLoading),
                          _buildMagicLinkTab(isLoading),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Guest Mode Action
                    const Divider(),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              ref.read(authNotifierProvider.notifier).continueAsGuest();
                              context.go(RouteConstants.guest);
                            },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('先不登入，直接以訪客模式體驗'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _signInEmailCtrl,
          labelText: '電子郵件',
          hintText: 'user@example.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          controller: _signInPasswordCtrl,
          labelText: '密碼',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(RouteConstants.passwordReset),
            child: const Text('忘記密碼？', style: TextStyle(fontSize: 12)),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () {
                  ref.read(authNotifierProvider.notifier).signInWithEmail(
                        _signInEmailCtrl.text.trim(),
                        _signInPasswordCtrl.text,
                      );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('登入帳號', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignUpTab(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _signUpNameCtrl,
          labelText: '稱呼 / 姓名',
          hintText: '您的暱稱',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 10),
        AuthTextField(
          controller: _signUpEmailCtrl,
          labelText: '電子郵件',
          hintText: 'user@example.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        AuthTextField(
          controller: _signUpPasswordCtrl,
          labelText: '設定密碼',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () {
                  ref.read(authNotifierProvider.notifier).signUpWithEmail(
                        _signUpEmailCtrl.text.trim(),
                        _signUpPasswordCtrl.text,
                        displayName: _signUpNameCtrl.text.trim().isNotEmpty
                            ? _signUpNameCtrl.text.trim()
                            : null,
                      );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('建立新帳號', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMagicLinkTab(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _magicEmailCtrl,
          labelText: '電子郵件',
          hintText: 'user@example.com',
          prefixIcon: Icons.mark_email_read_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        Text(
          '我們將發送一次性免密碼登入連結至您的信箱，點擊連結或輸入 6 位驗證碼即可快速登入。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () async {
                  final email = _magicEmailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    await ref.read(authNotifierProvider.notifier).sendMagicLink(email);
                    if (mounted) {
                      await context.push(RouteConstants.magicLinkSent, extra: email);
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('發送免密碼連結',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
