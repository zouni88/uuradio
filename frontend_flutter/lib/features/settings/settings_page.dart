import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/settings_local_ds.dart';
import '../../data/network/api_server_resolver.dart';
import '../../l10n_helper.dart';
import 'backup_service.dart';
import 'settings_controller.dart';

/// 设置页：语言 / 主题 / 主题色 / 码率偏好 / 导入导出 / 关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 语言
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(l10n.language),
            trailing: Text(
              _localeLabel(l10n, settings.localeCode),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            onTap: () => _pickLocale(context, ref, settings.localeCode),
          ),
          // 主题
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: Text(l10n.theme),
            trailing: Text(
              switch (settings.themeMode) {
                AppThemeMode.system => l10n.themeSystem,
                AppThemeMode.light => l10n.themeLight,
                AppThemeMode.dark => l10n.themeDark,
              },
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            onTap: () => _pickThemeMode(context, ref, settings.themeMode),
          ),
          // 主题色
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: Text(l10n.accentColor),
          ),
          _ColorPickerRow(selected: settings.seedColor),
          const Divider(indent: 16, endIndent: 16),
          // 码率偏好
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: Text(l10n.minBitratePref),
            trailing: Text(
              settings.minBitrate > 0
                  ? l10n.bitrateKbps(settings.minBitrate)
                  : l10n.bitrateAny,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            onTap: () => _pickBitrate(context, ref, settings.minBitrate),
          ),
          // 数据源（RadioBrowser 镜像，支持自建）
          ListTile(
            leading: const Icon(Icons.dns_rounded),
            title: Text(l10n.dataSource),
            subtitle: Text(
              settings.customMirror.isEmpty
                  ? l10n.dataSourceAuto
                  : settings.customMirror,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            onTap: () => _editMirror(context, ref, settings.customMirror),
          ),
          const Divider(indent: 16, endIndent: 16),
          // 对讲（PTT）：信令服务器 / 呼号 / TURN 兜底
          ListTile(
            leading: const Icon(Icons.cell_tower_rounded),
            title: Text(l10n.intercomServerUrl),
            subtitle: Text(
              settings.intercomServerUrl.isEmpty
                  ? l10n.intercomServerUrlHint
                  : settings.intercomServerUrl,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            onTap: () => _editIntercomServer(context, ref,
                settings.intercomServerUrl),
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: Text(l10n.intercomNickname),
            subtitle: Text(
              settings.intercomNickname.isEmpty
                  ? l10n.intercomNicknameHint
                  : settings.intercomNickname,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            onTap: () => _editIntercomNickname(context, ref,
                settings.intercomNickname),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(l10n.intercomTurn),
            subtitle: Text(
              settings.intercomTurnUrl.isEmpty
                  ? l10n.intercomTurnUrl
                  : settings.intercomTurnUrl,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            onTap: () => _editIntercomTurn(context, ref, settings),
          ),
          const Divider(indent: 16, endIndent: 16),
          // 数据与备份
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(l10n.exportFavorites),
            onTap: () async {
              try {
                final saved = await ref
                    .read(backupServiceProvider)
                    .exportFavorites();
                if (context.mounted && saved != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        saved.pathSegments.isNotEmpty
                            ? saved.pathSegments.last
                            : saved.toString(),
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.importFailed)),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.importFavorites),
            onTap: () async {
              try {
                final count =
                    await ref.read(backupServiceProvider).importFavorites();
                if (context.mounted && count != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.importSuccess(count))),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.importFailed)),
                  );
                }
              }
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.about),
            subtitle: Text(
              '${l10n.aboutDesc}\n${l10n.tvDataSourceDesc}\nv1.0.0',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localeLabel(AppLocalizations l10n, String? code) {
    if (code == null) return l10n.languageSystem;
    return switch (code) {
      'zh' => '中文',
      'en' => 'English',
      _ => code,
    };
  }

  Future<void> _pickLocale(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final l10n = context.l10n;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          RadioGroup<String>(
            groupValue: current ?? 'system',
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                RadioListTile(
                  value: 'system',
                  title: Text(l10n.languageSystem),
                ),
                const RadioListTile(value: 'zh', title: Text('中文')),
                const RadioListTile(value: 'en', title: Text('English')),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice != null) {
      await ref
          .read(settingsProvider.notifier)
          .setLocale(choice == 'system' ? null : choice);
    }
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final l10n = context.l10n;
    final choice = await showDialog<AppThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          RadioGroup<AppThemeMode>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                RadioListTile(
                  value: AppThemeMode.system,
                  title: Text(l10n.themeSystem),
                ),
                RadioListTile(
                  value: AppThemeMode.light,
                  title: Text(l10n.themeLight),
                ),
                RadioListTile(
                  value: AppThemeMode.dark,
                  title: Text(l10n.themeDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setThemeMode(choice);
    }
  }

  Future<void> _pickBitrate(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final l10n = context.l10n;
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.minBitratePref),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              children: [
                RadioListTile(
                  value: 0,
                  title: Text(l10n.bitrateAny),
                ),
                for (final b in const [64, 128, 192])
                  RadioListTile(value: b, title: Text(l10n.bitrateKbps(b))),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setMinBitrate(choice);
    }
  }

  /// 编辑自定义 API 镜像；空值 = 恢复自动发现。
  Future<void> _editMirror(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: current);
    final host = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataSourceDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'de1.api.radio-browser.info',
            helperText: l10n.dataSourceHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final normalized =
                  ApiServerResolver.normalizeHost(controller.text);
              if (normalized == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.dataSourceInvalid)),
                );
                return;
              }
              Navigator.pop(context, normalized);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (host == null) return;
    await ref.read(settingsProvider.notifier).setCustomMirror(host);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(host.isEmpty ? l10n.dataSourceReset : l10n.dataSourceSaved),
      ),
    );
  }

  /// 编辑对讲信令服务器（ws:// 或 wss://；空 = 清除）。
  Future<void> _editIntercomServer(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: current);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.intercomServerUrl),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'ws://192.168.1.5:8090/ws',
            helperText: l10n.intercomServerUrlHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty &&
                  !v.startsWith('ws://') &&
                  !v.startsWith('wss://')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.dataSourceInvalid)),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (url == null) return;
    await ref.read(settingsProvider.notifier).setIntercomServerUrl(url);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.intercomSaved)),
    );
  }

  Future<void> _editIntercomNickname(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: current);
    final nick = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.intercomNickname),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: InputDecoration(helperText: l10n.intercomNicknameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (nick == null) return;
    await ref.read(settingsProvider.notifier).setIntercomNickname(nick);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.intercomSaved)),
    );
  }

  /// 编辑 TURN 中继（三字段；URL 空 = 不启用）。
  Future<void> _editIntercomTurn(
    BuildContext context,
    WidgetRef ref,
    AppSettings current,
  ) async {
    final l10n = context.l10n;
    final urlCtrl = TextEditingController(text: current.intercomTurnUrl);
    final userCtrl = TextEditingController(text: current.intercomTurnUser);
    final passCtrl = TextEditingController(text: current.intercomTurnPass);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.intercomTurn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: l10n.intercomTurnUrl),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(hintText: l10n.intercomTurnUser),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(hintText: l10n.intercomTurnPass),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await ref.read(settingsProvider.notifier).setIntercomTurn(
          url: urlCtrl.text,
          user: userCtrl.text,
          pass: passCtrl.text,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.intercomSaved)),
    );
  }
}

/// 主题色选择行。
class _ColorPickerRow extends ConsumerWidget {
  const _ColorPickerRow({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        children: [
          for (final value in AppTheme.palette)
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () =>
                  ref.read(settingsProvider.notifier).setSeedColor(value),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.seedColorOf(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == value
                        ? Colors.white
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected == value
                      ? [
                          BoxShadow(
                            color: AppTheme.seedColorOf(value)
                                .withValues(alpha: 0.55),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: selected == value
                    ? const Icon(Icons.check_rounded,
                        size: 20, color: Colors.black)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// 备份服务 provider（依赖 Ref，页面级创建即可）。
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
