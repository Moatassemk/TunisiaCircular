import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:clac_mobile/shared/strings.dart';

class ImpactScreen extends StatefulWidget {
  const ImpactScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _loadReport();
  }

  Future<Map<String, dynamic>> _loadReport() => widget.api.personalImpact();

  Future<void> refresh() async {
    final request = _loadReport();
    setState(() {
      future = request;
    });
    await request;
  }

  Future<void> _copyReport(Map<String, dynamic> report) async {
    final rows = (report['monthly'] as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final csv = StringBuffer(
      'month,transactions,material_kg,estimated_co2e_kg\n',
    );
    for (final row in rows) {
      csv.writeln(
        '${row['month']},${row['transactions']},${row['material_kg']},${row['estimated_co2e_kg']}',
      );
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (mounted) {
      final snackbarMsg = context.clac(
        '12-month impact CSV copied to clipboard.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snackbarMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
              onRetry: refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = snapshot.data!;
          final stats = Map<String, dynamic>.from(report['summary'] as Map);
          final monthly = (report['monthly'] as List? ?? const [])
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          final carbon =
              double.tryParse(stats['estimated_co2e_kg']?.toString() ?? '0') ??
              0;
          final waste =
              double.tryParse(stats['material_kg']?.toString() ?? '0') ?? 0;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Eyebrow(context.clac('YOUR IMPACT')),
              const SizedBox(height: 7),
              Text(
                context.clac('Materials in motion'),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 5),
              Text(
                context.clac(
                  'Every verified exchange keeps material in the loop and carbon out of the air.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _ImpactHero(
                carbonKg: carbon,
                wasteKg: waste,
                transactions:
                    int.tryParse(stats['transactions']?.toString() ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  AchievementChip(
                    icon: Icons.swap_horiz,
                    label: context.clac('First exchange'),
                    unlocked:
                        (int.tryParse(
                              stats['transactions']?.toString() ?? '0',
                            ) ??
                            0) >
                        0,
                  ),
                  AchievementChip(
                    icon: Icons.scale_outlined,
                    label: context.clac('100 kg diverted'),
                    unlocked: waste >= 100,
                  ),
                  AchievementChip(
                    icon: Icons.forest_outlined,
                    label: context.clac('1 tonne diverted'),
                    unlocked: waste >= 1000,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: context.clac('Waste Diverted'),
                      value: '${formatValue(waste.round())} kg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: context.clac('Avg Distance'),
                      value: '${formatValue(stats['average_distance_km'])} km',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Eyebrow(context.clac('MONTHLY ACTIVITY · LAST 12 MONTHS')),
              const SizedBox(height: 8),
              if (monthly.isEmpty)
                Text(
                  context.clac(
                    'Completed exchanges will appear in your report.',
                  ),
                )
              else
                ...monthly.map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['month']?.toString() ?? ''),
                    subtitle: Text(
                      '${row['transactions']} ${context.clac('exchanges')} · ${formatValue(row['material_kg'])} ${context.clac('kg materials')}',
                    ),
                    trailing: Text(
                      '${formatValue(row['estimated_co2e_kg'])} kg CO₂e',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.clac('How the estimate is calculated')),
                subtitle: Text(
                  context.clac(
                    'Estimates use saved exchange results. The sources listed below are the currently active factors.',
                  ),
                ),
                children: (report['factors'] as List? ?? const []).map((raw) {
                  final factor = Map<String, dynamic>.from(raw as Map);
                  return ListTile(
                    dense: true,
                    title: Text(factor['factor_key']?.toString() ?? ''),
                    subtitle: Text(
                      '${factor['description'] ?? ''}\n${context.clac('Source:')} ${factor['source'] ?? 'Not specified'}',
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _copyReport(report),
                icon: const Icon(Icons.download_outlined),
                label: Text(context.clac('Copy 12-month CSV report')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ImpactHero extends StatelessWidget {
  const _ImpactHero({
    required this.carbonKg,
    required this.wasteKg,
    required this.transactions,
  });

  final double carbonKg;
  final double wasteKg;
  final int transactions;

  @override
  Widget build(BuildContext context) {
    final trees = carbonKg / 21;
    final carKm = carbonKg / 0.17;
    final nextMilestone = ((carbonKg / 100).floor() + 1) * 100;
    final progress = carbonKg == 0 ? 0.0 : (carbonKg % 100) / 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123528), Color(0xFF2C7658)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(clacRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CO₂e AVOIDED',
                  style: TextStyle(
                    color: Color(0xFFF5C77C),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$transactions exchange${transactions == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${formatValue(carbonKg.round())} kg',
            style: const TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 42,
              height: 1.05,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatValue(wasteKg.round())} kg of material kept in the loop',
            style: const TextStyle(color: Color(0xFFD2E5D8), fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Equivalent(
                  icon: Icons.forest_outlined,
                  value: formatValue(trees.round()),
                  label: 'trees for a year',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Equivalent(
                  icon: Icons.directions_car_outlined,
                  value: formatValue(carKm.round()),
                  label: 'km not driven',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: .18),
              color: const Color(0xFFF5C77C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            carbonKg == 0
                ? 'Complete your first exchange to start your impact story.'
                : '${formatValue((nextMilestone - carbonKg).round())} kg to your next ${formatValue(nextMilestone)} kg milestone.',
            style: const TextStyle(color: Color(0xFFD2E5D8), fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _Equivalent extends StatelessWidget {
  const _Equivalent({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFF5C77C), size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFD2E5D8), fontSize: 9.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AchievementChip extends StatelessWidget {
  const AchievementChip({
    required this.icon,
    required this.label,
    required this.unlocked,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => FilterChip(
    selected: unlocked,
    onSelected: null,
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selectedColor: unlocked ? const Color(0xFFE8F2E9) : const Color(0xFFF4F6F1),
    checkmarkColor: unlocked ? pine : null,
    avatar: unlocked ? Icon(icon, color: pine, size: 16) : null,
    disabledColor: const Color(0xFFF4F6F1),
  );
}
