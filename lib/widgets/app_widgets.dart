import 'package:flutter/material.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.label,
    this.showBack = true,
    this.onBack,
  });

  final String label;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack) ...[
          GestureDetector(
            onTap: onBack ?? () => Navigator.pop(context),
            child: Container(
              width: 35,
              height: 31,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE6EAF3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  '‹',
                  style: TextStyle(
                    color: Color(0xFF202640),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B839B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6EAF3)),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202640),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF7B839B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
  });

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Text(
            'Loading / Preview',
            style: TextStyle(
              color: Color(0xFF202640),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

enum StateKind { loading, error, success, info }

/// Inline state feedback for real loading / error / success conditions.
class StateBanner extends StatelessWidget {
  const StateBanner({
    super.key,
    required this.text,
    this.kind = StateKind.info,
    this.action,
    this.onAction,
  });

  final String text;
  final StateKind kind;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      StateKind.loading => (const Color(0xFFE9EEFF), const Color(0xFF4365E8)),
      StateKind.error => (const Color(0xFFFFF0F2), const Color(0xFFE45E73)),
      StateKind.success => (const Color(0xFFE5F8F3), const Color(0xFF18A891)),
      StateKind.info => (const Color(0xFFF1ECFF), const Color(0xFF7E66D9)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (kind == StateKind.loading) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1F2540),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
