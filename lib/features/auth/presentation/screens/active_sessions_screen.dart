import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_state.dart';
import '../providers/auth_providers.dart';
import '../widgets/device_card.dart';

class ActiveSessionsScreen extends ConsumerWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    if (authState is! Authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('多設備連線管理')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('請先登入帳號以管理已登入之設備'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final devicesAsync = ref.watch(activeDevicesStreamProvider);
    final currentDeviceIdAsync = ref.watch(currentDeviceIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('已登入設備管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新整理',
            onPressed: () {
              ref
                  .read(sessionRegistryRepositoryProvider)
                  .refreshActiveDevices(userId: authState.user.id);
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('目前沒有已註冊的設備'));
          }

          final currentDeviceId = currentDeviceIdAsync.valueOrNull ?? '';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                '以下是目前連結至您帳號的終端設備。您可以隨時踢出非本人使用或已遺失的設備。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ...devices.map(
                (d) => DeviceCard(
                  device: d,
                  onKick: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('確認踢出設備？'),
                        content: Text('將強制使「${d.deviceName}」登出並中斷其資料同步。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            child: const Text('確認踢出'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(sessionRegistryRepositoryProvider).kickDevice(
                            deviceId: d.id,
                            userId: authState.user.id,
                          );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('強制登出所有其他設備？'),
                      content: const Text('除了目前這台設備之外，所有已登入此帳號的手機、平板與電腦都將被強制登出。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: const Text('確認全部登出'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && currentDeviceId.isNotEmpty) {
                    await ref.read(sessionRegistryRepositoryProvider).kickAllOtherDevices(
                          currentDeviceId: currentDeviceId,
                          userId: authState.user.id,
                        );
                  }
                },
                icon: const Icon(Icons.devices_other_rounded, color: Colors.redAccent),
                label: const Text('強制登出所有其他設備', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('載入設備失敗: $err')),
      ),
    );
  }
}
