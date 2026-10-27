import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/neon.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/models/intercom_models.dart';
import '../../l10n_helper.dart';
import '../settings/settings_controller.dart';
import 'intercom_controller.dart';
import 'widgets/ptt_button.dart';
import 'widgets/speaking_indicator.dart';

/// 对讲页：未入房 = 频道加入表单；已入房 = 成员列表 + PTT 大按钮。
class IntercomPage extends ConsumerStatefulWidget {
  const IntercomPage({super.key});

  @override
  ConsumerState<IntercomPage> createState() => _IntercomPageState();
}

class _IntercomPageState extends ConsumerState<IntercomPage> {
  final _channelCtrl = TextEditingController();

  @override
  void dispose() {
    _channelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(intercomProvider);
    final hasServer = ref.watch(settingsProvider).intercomServerUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: NeonText(l10n.tabIntercom, color: scheme.primary),
        actions: [
          if (state.joined)
            TextButton(
              onPressed: () =>
                  ref.read(intercomProvider.notifier).leaveChannel(),
              child: Text(l10n.intercomLeave),
            ),
        ],
      ),
      body: SafeArea(
        child: state.joined
            ? _joinedView(context, state)
            : _joinView(context, state, hasServer),
      ),
    );
  }

  // ---- 未入房 ----

  Widget _joinView(
      BuildContext context, IntercomUiState state, bool hasServer) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        NeonText(
          l10n.tabIntercom,
          color: scheme.primary,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasServer
              ? l10n.intercomChannelHint
              : l10n.intercomServerRequired,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 24),
        NeonBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _channelCtrl,
                decoration: InputDecoration(hintText: l10n.intercomChannelHint),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: hasServer ? _join : null,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(l10n.intercomJoin),
                ),
              ),
            ],
          ),
        ),
        _noticeBanner(context, state),
      ],
    );
  }

  void _join() {
    final ch = _channelCtrl.text.trim();
    if (ch.isEmpty) return;
    ref.read(intercomProvider.notifier).joinChannel(ch);
  }

  // ---- 已入房 ----

  Widget _joinedView(BuildContext context, IntercomUiState state) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final connecting = state.ptt == PttState.connecting ||
        state.ptt == PttState.connected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Icon(Icons.hub_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                state.channel,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                connecting && state.members.length <= 1
                    ? l10n.intercomNotConnected
                    : '${state.members.length} OP',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: connecting && state.members.isEmpty
              ? ListView(
                  shrinkWrap: true,
                  children: const [
                    StationTileSkeleton(),
                    StationTileSkeleton(),
                    StationTileSkeleton(),
                  ],
                )
              : _memberList(context, state),
        ),
        _noticeBanner(context, state),
        SpeakingIndicator(
          ptt: state.ptt,
          text: state.ptt == PttState.talking
              ? l10n.pttTalking
              : l10n.pttListening(state.speakerNick),
        ),
        const SizedBox(height: 12),
        PttButton(
          ptt: state.ptt,
          enabled: state.canStartTalk,
          label: switch (state.ptt) {
            PttState.talking => l10n.pttTalking,
            PttState.requesting => l10n.pttRequesting,
            PttState.listening => l10n.pttListening(state.speakerNick),
            _ => l10n.pttHoldToTalk,
          },
          onDown: () => ref.read(intercomProvider.notifier).pointerDown(),
          onUp: () => ref.read(intercomProvider.notifier).pointerUp(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _memberList(BuildContext context, IntercomUiState state) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (state.members.isEmpty) {
      return Center(
        child: Text(
          l10n.intercomNoMembers,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: state.members.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return NeonDivider(thickness: 1, color: scheme.primary);
        }
        final m = state.members[i - 1];
        final speaking =
            state.ptt == PttState.listening && m.nick == state.speakerNick;
        return NeonBox(
          color: speaking ? scheme.primary : null,
          glow: speaking ? 18 : 8,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                speaking ? Icons.graphic_eq_rounded : Icons.person_rounded,
                size: 18,
                color: speaking ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.nick,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        speaking ? FontWeight.w700 : FontWeight.w500,
                    color: speaking ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- 通知 ----

  Widget _noticeBanner(BuildContext context, IntercomUiState state) {
    final code = state.notice;
    if (code == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = switch (code) {
      'server_required' => l10n.intercomServerRequired,
      'mic_denied' => l10n.intercomMicDenied,
      'room_full' => l10n.intercomRoomFull,
      'floor_busy' => l10n.intercomFloorBusy,
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => ref.read(intercomProvider.notifier).dismissNotice(),
        child: NeonBox(
          color: scheme.error,
          glow: 10,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 12.5, color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
