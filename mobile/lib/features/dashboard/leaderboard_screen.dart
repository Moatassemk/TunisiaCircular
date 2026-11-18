import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _fetchRanking();
  }

  Future<Map<String, dynamic>> _fetchRanking() async {
    final response = await widget.api.leaderboard();
    return {
      'topGenerators': List<dynamic>.from(
        response['topGenerators'] as List? ?? [],
      ),
      'topProcessors': List<dynamic>.from(
        response['topProcessors'] as List? ?? [],
      ),
    };
  }

  Future<void> refresh() async {
    final request = _fetchRanking();
    setState(() {
      future = request;
    });
    await request;
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
          final data = snapshot.data!;
          final generators = data['topGenerators'] as List<dynamic>;
          final processors = data['topProcessors'] as List<dynamic>;
          final isBuyer = widget.user['role'] == 'processor';

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Eyebrow('TOP GENERATORS'),
                const SizedBox(height: 10),
                ..._buildList(generators, isBuyer: !isBuyer),
                const SizedBox(height: 20),
                const Eyebrow('TOP BUYERS'),
                const SizedBox(height: 10),
                ..._buildList(processors, isBuyer: isBuyer),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildList(List<dynamic> items, {required bool isBuyer}) {
    if (items.isEmpty) {
      return [
        const EmptyStateMobile(
          title: 'No data yet',
          body: 'Activity will appear here soon.',
        ),
      ];
    }
    return items.take(5).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final rank = items.indexOf(raw) + 1;
      final color = rank == 1
          ? amber
          : rank == 2
          ? muted
          : pine;
      return Card(
        color: Theme.of(context).cardTheme.color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: Color(0xFFE1E6DF)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            item['name']?.toString() ?? 'Unknown',
            style: const TextStyle(
              color: pineDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Text(
            '${formatValue(item['total_kg'] ?? 0)} kg',
            style: const TextStyle(
              color: pine,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
    }).toList();
  }
}
