import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/widgets.dart';

class ProcessorScreen extends StatefulWidget {
  const ProcessorScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<ProcessorScreen> createState() => _ProcessorScreenState();
}

class _ProcessorScreenState extends State<ProcessorScreen> {
  String? selectedWaste;
  String? selectedRegion;

  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.processors(selectedWaste, selectedRegion);
  }

  Future<void> refresh() async {
    final request = widget.api.processors(selectedWaste, selectedRegion);
    setState(() {
      future = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selectedWaste ?? 'all'),
                    decoration: const InputDecoration(labelText: 'Waste type'),
                    initialValue: selectedWaste ?? 'all',
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All materials'),
                      ),
                      ...materials.entries.map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      selectedWaste = v == 'all' ? null : v;
                      future = widget.api.processors(
                        selectedWaste,
                        selectedRegion,
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selectedRegion ?? 'all'),
                    decoration: const InputDecoration(labelText: 'Governorate'),
                    initialValue: selectedRegion ?? 'all',
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All regions'),
                      ),
                      ...governorates.map(
                        (g) => DropdownMenuItem(value: g, child: Text(g)),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      selectedRegion = v == 'all' ? null : v;
                      future = widget.api.processors(
                        selectedWaste,
                        selectedRegion,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
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
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const EmptyStateMobile(
                    title: 'No processors found',
                    body: 'Try different filters.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final proc = items[index] as Map<String, dynamic>;
                      return Card(
                        color: Theme.of(context).cardTheme.color,
                        elevation: 0,
                        child: ListTile(
                          title: Text(proc['name']?.toString() ?? 'Processor'),
                          subtitle: Text('${proc['gouvernorat'] ?? ''}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
