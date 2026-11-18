import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

const governorates = <String>[
  'Ariana',
  'Beja',
  'Ben Arous',
  'Bizerte',
  'Gabes',
  'Gafsa',
  'Jendouba',
  'Kairouan',
  'Kasserine',
  'Kebili',
  'Kef',
  'Mahdia',
  'Manouba',
  'Medenine',
  'Monastir',
  'Nabeul',
  'Sfax',
  'Sidi Bouzid',
  'Siliana',
  'Sousse',
  'Tataouine',
  'Tozeur',
  'Tunis',
  'Zaghouan',
];

const materials = <String, String>{
  'pomace': 'Olive pomace',
  'usedCookingOil': 'Used cooking oil',
  'organicFood': 'Organic food waste',
  'foodWaste': 'Food waste',
  'pomace_stones': 'Olive stones',
};

const regionCoordinates = <String, (double, double)>{
  'Ariana': (36.8625, 10.1956),
  'Beja': (36.7256, 9.1817),
  'Ben Arous': (36.753, 10.2189),
  'Bizerte': (37.2744, 9.8739),
  'Gabes': (33.8815, 10.0982),
  'Gafsa': (34.425, 8.7842),
  'Jendouba': (36.5011, 8.7802),
  'Kairouan': (35.6781, 10.0963),
  'Kasserine': (35.1676, 8.8365),
  'Kebili': (33.7045, 8.969),
  'Kef': (36.1742, 8.7049),
  'Mahdia': (35.5047, 11.0622),
  'Manouba': (36.8078, 10.1011),
  'Medenine': (33.3549, 10.5055),
  'Monastir': (35.7643, 10.8113),
  'Nabeul': (36.4513, 10.7357),
  'Sfax': (34.74, 10.76),
  'Sidi Bouzid': (35.0382, 9.4858),
  'Siliana': (36.0849, 9.3708),
  'Sousse': (35.8256, 10.637),
  'Tataouine': (32.9297, 10.4518),
  'Tozeur': (33.9197, 8.1335),
  'Tunis': (36.8065, 10.1815),
  'Zaghouan': (36.4029, 10.1429),
};

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String formatValue(dynamic value) {
  if (value == null) return '0';
  final text = value.toString();
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String materialLabel(dynamic value) =>
    materials[value] ?? value?.toString() ?? '';

String humanStatus(String? value) {
  final text = (value ?? '').replaceAll('_', ' ').trim();
  if (text.isEmpty) return 'Unknown';
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String relativeTime(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}/${date.year}';
}

String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('ClientException')) {
    return "We couldn't reach the CLAC network. Check your connection and try again.";
  }
  if (text.contains('TimeoutException')) {
    return 'The request took too long. Please try again.';
  }
  if (text.startsWith('Exception: ')) return text.substring(11);
  return text;
}

void hapticTap() => HapticFeedback.selectionClick();
void hapticSuccess() => HapticFeedback.mediumImpact();
void hapticError() => HapticFeedback.heavyImpact();

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, this.onDark = false, super.key});
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = onDark
        ? Colors.white
        : dark
        ? Theme.of(context).colorScheme.onSurface
        : pineDark;
    final subtitleColor = onDark
        ? const Color(0xFFB9CDBE)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 40,
          height: compact ? 32 : 40,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: const CustomPaint(painter: ClacMarkPainter()),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CLAC',
              style: TextStyle(
                color: titleColor,
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(
                'Circular links, real impact',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ClacMarkPainter extends CustomPainter {
  const ClacMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);
    final bg = Paint()..color = const Color(0xff1e5a43);
    canvas.drawCircle(const Offset(24, 24), 23, bg);
    final gold = Paint()
      ..color = const Color(0xfff5c77c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(11, 11, 26, 26), -2.5, 1.5, false, gold);
    canvas.drawArc(const Rect.fromLTWH(11, 11, 26, 26), .65, 1.5, false, white);
    final arrow = Paint()
      ..color = const Color(0xfff5c77c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Path()
      ..moveTo(10.1, 13.9)
      ..lineTo(11.8, 19.4)
      ..lineTo(17.3, 17.9);
    canvas.drawPath(a, arrow);
    final b = Path()
      ..moveTo(37.9, 34.1)
      ..lineTo(36.1, 28.7)
      ..lineTo(30.7, 30.2);
    canvas.drawPath(b, white);
    final leaf = Path()
      ..moveTo(19, 27.2)
      ..cubicTo(19.3, 22.1, 24.6, 18.5, 31.8, 18.9)
      ..cubicTo(31.1, 25.7, 27.6, 30.1, 22.5, 30)
      ..cubicTo(20.5, 29.9, 18.9, 28.9, 19, 27.2)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xfff5c77c));
    canvas.drawLine(
      const Offset(20.5, 29.2),
      const Offset(29.2, 22),
      Paint()
        ..color = const Color(0xff205b45)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small all-caps label used above headings and inside cards.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color ?? Theme.of(context).colorScheme.primary,
      letterSpacing: 1.4,
    ),
  );
}

/// Page-level heading with optional subtitle and trailing action.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 18),
    super.key,
  });
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Eyebrow(eyebrow!),
                  const SizedBox(height: 7),
                ],
                Text(title, style: theme.textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12),
    super.key,
  });
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                hapticTap();
                onAction!();
              },
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class ClacCard extends StatelessWidget {
  const ClacCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = clacRadius,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? theme.colorScheme.outlineVariant),
    );
    return Material(
      color: color ?? theme.cardTheme.color ?? theme.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                hapticTap();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.icon,
    this.hint,
    this.onTap,
    this.highlight = false,
    this.accent,
    super.key,
  });
  final String label;
  final String value;
  final IconData? icon;
  final String? hint;
  final VoidCallback? onTap;
  final bool highlight;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = highlight ? Colors.white : theme.colorScheme.onSurface;
    final sub = highlight
        ? const Color(0xFFC6DCCE)
        : theme.colorScheme.onSurfaceVariant;
    final accentColor =
        accent ??
        (highlight ? const Color(0xFFF5C77C) : theme.colorScheme.primary);
    return ClacCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      color: highlight ? (dark ? const Color(0xFF24513C) : pineDark) : null,
      borderColor: highlight ? Colors.transparent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: sub),
                ),
              ),
              if (icon != null)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: highlight
                        ? Colors.white.withValues(alpha: .12)
                        : accentColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: fg,
              fontFamily: 'serif',
              fontSize: 27,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: sub),
            ),
          ],
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({required this.label, required this.value, super.key});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) =>
      MetricCard(label: label, value: formatValue(value));
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = color ?? theme.colorScheme.primary;
    return Material(
      color: theme.cardTheme.color ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(clacRadius),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          hapticTap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: tone),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BannerTone { info, success, warning, danger }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.title,
    required this.body,
    this.tone = BannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final String title;
  final String body;
  final BannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (bg, fg, accent) = switch (tone) {
      BannerTone.success => (
        dark ? const Color(0xFF1C3A2B) : clacGreenSoft,
        dark ? const Color(0xFFD9EEE0) : pineDark,
        dark ? const Color(0xFF8AD0A8) : pine,
      ),
      BannerTone.warning => (
        dark ? const Color(0xFF3C2F1E) : clacAmberSoft,
        dark ? const Color(0xFFFBE7CD) : const Color(0xFF5A3A12),
        dark ? const Color(0xFFF0BF85) : amberDark,
      ),
      BannerTone.danger => (
        dark ? const Color(0xFF3F2521) : clacDangerSoft,
        dark ? const Color(0xFFFFDAD3) : const Color(0xFF6E241C),
        dark ? const Color(0xFFFFB4A9) : clacDanger,
      ),
      BannerTone.info => (
        dark ? const Color(0xFF1E3240) : clacInfoSoft,
        dark ? const Color(0xFFD8EAF5) : const Color(0xFF234A63),
        dark ? const Color(0xFF9EC9E3) : clacInfo,
      ),
    };
    final resolvedIcon =
        icon ??
        switch (tone) {
          BannerTone.success => Icons.check_circle_outline,
          BannerTone.warning => Icons.info_outline,
          BannerTone.danger => Icons.error_outline,
          BannerTone.info => Icons.lightbulb_outline,
        };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(clacRadius),
        border: Border.all(color: accent.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, color: accent, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: .82),
                    height: 1.45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        actionLabel!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                          decoration: TextDecoration.underline,
                          decorationColor: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InfoBanner(
      title: 'Something went wrong',
      body: message,
      tone: BannerTone.danger,
    ),
  );
}

class EmptyStateMobile extends StatelessWidget {
  const EmptyStateMobile({
    required this.title,
    required this.body,
    this.action,
    this.icon = Icons.inbox_outlined,
    super.key,
  });
  final String title;
  final String body;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyStateMobile(
    icon: Icons.cloud_off_outlined,
    title: 'Connection interrupted',
    body: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh, size: 17),
      label: const Text('Try again'),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {this.icon = true, super.key});
  final String status;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final key = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    late final IconData glyph;
    if (key.contains('verified') ||
        key.contains('completed') ||
        key.contains('approved') ||
        key.contains('active') ||
        key.contains('sold')) {
      bg = dark ? const Color(0xFF234534) : clacGreenSoft;
      fg = dark ? const Color(0xFF9DDEB6) : pine;
      glyph = Icons.check_circle_outline;
    } else if (key.contains('reject') ||
        key.contains('fail') ||
        key.contains('inactive') ||
        key.contains('cancel')) {
      bg = dark ? const Color(0xFF432923) : clacDangerSoft;
      fg = dark ? const Color(0xFFFFB4A9) : clacDanger;
      glyph = Icons.cancel_outlined;
    } else if (key.contains('pending') ||
        key.contains('review') ||
        key.contains('draft') ||
        key.contains('reserved')) {
      bg = dark ? const Color(0xFF3D3020) : clacAmberSoft;
      fg = dark ? const Color(0xFFF5C99A) : amberDark;
      glyph = Icons.schedule;
    } else {
      bg = dark ? const Color(0xFF24313A) : const Color(0xFFEDF2F5);
      fg = dark ? const Color(0xFFB8D3E2) : const Color(0xFF486475);
      glyph = Icons.circle_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon) ...[
            Icon(glyph, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            humanStatus(status),
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClacCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: theme.colorScheme.primary, size: 18),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.number,
    required this.title,
    required this.body,
    super.key,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: amber.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: amberDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    this.size = 40,
    this.color,
    super.key,
  });
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final baseColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? 'C' : initials,
        style: TextStyle(
          color: baseColor,
          fontSize: size * .33,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading states
// ---------------------------------------------------------------------------
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
    super.key,
  });
  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: .08);
    return FadeTransition(
      opacity: Tween<double>(
        begin: .45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.itemHeight = 92,
    super.key,
  });
  final int count;
  final EdgeInsetsGeometry padding;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) => Container(
      height: itemHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(clacRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 42, height: 42, radius: 21),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 220, height: 10),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 9),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------
Future<void> showClacSuccessSheet(
  BuildContext context, {
  required String title,
  required String body,
  String actionLabel = 'Done',
  VoidCallback? onAction,
}) async {
  hapticSuccess();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: clacGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: pine, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onAction?.call();
                },
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
