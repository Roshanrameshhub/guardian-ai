import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';


class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({
    super.key,
    this.callerName = 'Mom',
    this.callerNumber = '+1 (555) 234-5678',
  });

  final String callerName;
  final String callerNumber;

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _isAnswered = false;
  int _seconds = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeaker = true;

  void _answerCall() {
    setState(() => _isAnswered = true);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    }
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(color: AppColors.glassBorder, width: 2),
                ),
                child: Center(
                  child: Text(
                    widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : 'C',
                    style: AppTextStyles.displayLg.copyWith(color: AppColors.primaryPulse),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.callerName,
                style: AppTextStyles.headlineLg.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.callerNumber,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isAnswered ? _formatDuration(_seconds) : 'Incoming call...',
                style: AppTextStyles.labelLg.copyWith(
                  color: _isAnswered ? AppColors.tertiary : AppColors.primaryPulse,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isAnswered) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionBtn(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      active: _isMuted,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    _CallActionBtn(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      onTap: () {},
                    ),
                    _CallActionBtn(
                      icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      active: _isSpeaker,
                      onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: _endCall,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 8),
                          Text('Decline', style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _answerCall,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.tertiary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call, color: Colors.white, size: 36),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.12, 1.12),
                                duration: 800.ms,
                              ),
                          const SizedBox(height: 8),
                          Text('Accept', style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionBtn extends StatelessWidget {
  const _CallActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: active ? AppColors.white : AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? AppColors.background : AppColors.onSurface,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.labelSm),
        ],
      ),
    );
  }
}
