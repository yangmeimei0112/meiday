import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/native_integration_providers.dart';
import '../providers/sync_providers.dart';

class SyncSettingsSheet extends ConsumerStatefulWidget {
  const SyncSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncSettingsSheet(),
    );
  }

  @override
  ConsumerState<SyncSettingsSheet> createState() => _SyncSettingsSheetState();
}

class _SyncSettingsSheetState extends ConsumerState<SyncSettingsSheet> {
  bool _isExportingWidget = false;
  bool _isConnectingExternal = false;
  String? _statusFeedback;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.currentUser?.id ?? 'guest';
    final isGuest = authState.isGuest;
    final pendingCount = ref.watch(pendingOutboxCountStreamProvider).value ?? 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '雲端同步與原生整合',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feedback banner
              if (_statusFeedback != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusFeedback!,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Supabase Cloud Sync Card
              _buildSectionCard(
                title: 'Supabase 本地優先雲同步',
                icon: Icons.cloud_sync,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? '目前處於訪客模式 (本機 guest.db 隔離)' : '使用者 ID: $userId',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '離線待同步佇列：$pendingCount 筆',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('立即同步'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final res = await ref
                                .read(syncCoordinatorProvider.notifier)
                                .triggerManualSync(userId);
                            setState(() {
                              _statusFeedback = '手動同步已觸發：$res';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Mobile Home Widget Snapshot Card
              _buildSectionCard(
                title: '行動端與桌面小工具 (HomeWidget)',
                icon: Icons.widgets_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '將今日行程與重要待辦輸出為輕量快照 JSON (<50KB)，支援 iOS/Android 桌面小工具秒顯。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: _isExportingWidget
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_to_mobile, size: 16),
                      label: const Text('導出並刷新今日小工具快照'),
                      onPressed: _isExportingWidget
                          ? null
                          : () async {
                              setState(() => _isExportingWidget = true);
                              try {
                                final snapshot = await ref
                                    .read(widgetSnapshotExporterProvider)
                                    .exportSnapshot();
                                setState(() {
                                  _statusFeedback =
                                      '小工具快照導出成功！(${snapshot.byteSize} bytes, 事件數: ${snapshot.events.length})';
                                });
                              } catch (e) {
                                setState(() {
                                  _statusFeedback = '導出失敗：$e';
                                });
                              } finally {
                                setState(() => _isExportingWidget = false);
                              }
                            },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. External Calendar Sync (Relay & Desktop OAuth)
              _buildSectionCard(
                title: '外部日曆整合 (Google / Apple / Outlook)',
                icon: Icons.calendar_month_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '行動端中繼代理 (Mobile Relay) 雙向橋接，桌面端支援 Loopback OAuth (最多 100 位朋友測試，免 CASA 審查)。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.sync_alt, size: 16),
                            label: const Text('裝置日曆中繼同步'),
                            onPressed: () async {
                              final relay = ref.read(externalCalendarRelayProvider);
                              final hasPerm = await relay.hasCalendarPermissions();
                              if (!hasPerm) {
                                await relay.requestCalendarPermissions();
                              }
                              final events = await relay.fetchEventsFromDevice(
                                rangeStart: DateTime.now().subtract(const Duration(days: 7)),
                                rangeEnd: DateTime.now().add(const Duration(days: 7)),
                              );
                              setState(() {
                                _statusFeedback = '已掃描裝置行事曆事件：${events.length} 筆';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.link, size: 16),
                            label: const Text('Google 桌面授權'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isConnectingExternal
                                ? null
                                : () async {
                                    setState(() => _isConnectingExternal = true);
                                    try {
                                      final oauth = ref.read(desktopOAuthServiceProvider);
                                      final code = await oauth.acquireAuthCode(
                                        clientId: 'chronohub-desktop-client.apps.googleusercontent.com',
                                        scopes: ['https://www.googleapis.com/auth/calendar.events'],
                                      );
                                      setState(() {
                                        _statusFeedback = 'Google OAuth 授權成功！Code: $code';
                                      });
                                    } catch (e) {
                                      setState(() {
                                        _statusFeedback = '授權中斷或失敗：$e';
                                      });
                                    } finally {
                                      setState(() => _isConnectingExternal = false);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
