import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/strings.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.api,
    required this.onUpdateUser,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onUpdateUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> user;
  late Future<Map<String, dynamic>> summary;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    summary = widget.api.profileSummary();
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProfileSheet(user: user, api: widget.api),
    );
    if (result != null && mounted) {
      setState(() => user = {...user, ...result});
      widget.onUpdateUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'User';
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final joined = DateTime.tryParse(user['created_at']?.toString() ?? '');
    final joinedText = joined == null
        ? context.clac('Date unavailable')
        : MaterialLocalizations.of(context).formatMonthYear(joined);
    final roleLabel = user['role'] == 'collector'
        ? 'Collection specialist'
        : user['role']?.toString() ?? 'Member';

    return Scaffold(
      appBar: AppBar(title: Text(context.clac('Profile'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: amber.withValues(alpha: 0.2),
                  backgroundImage:
                      (user['profile_photo']?.toString().startsWith(
                            'https://',
                          ) ??
                          false)
                      ? NetworkImage(user['profile_photo'].toString())
                      : null,
                  child:
                      user['profile_photo']?.toString().startsWith(
                            'https://',
                          ) ==
                          true
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: amber,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['company_name']?.toString() ?? 'Independent',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 8),
                Text(
                  context.clac(roleLabel).toUpperCase(),
                  style: const TextStyle(
                    color: pine,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.clac('Member since')} $joinedText',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: summary,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() {
                    summary = widget.api.profileSummary();
                  }),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data!;
              final seller = user['role'] == 'generator';
              final collector = user['role'] == 'collector';
              final primaryCount = seller
                  ? data['listing_count']
                  : data['transaction_count'];
              final weight = seller
                  ? data['monthly_listing_kg']
                  : data['transaction_kg'];
              final recent = (data['recent_activity'] as List? ?? const [])
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runSpacing: 18,
                    children: [
                      if (collector) ...[
                        _ProfileStat(
                          label: context.clac('Collection points'),
                          value: formatValue(data['collection_point_count']),
                          icon: Icons.add_location_alt_outlined,
                        ),
                        _ProfileStat(
                          label: context.clac('Verified points'),
                          value: formatValue(
                            data['verified_collection_point_count'],
                          ),
                          icon: Icons.verified_outlined,
                        ),
                      ] else ...[
                        _ProfileStat(
                          label: context.clac(seller ? 'Listed' : 'Deals'),
                          value: formatValue(primaryCount),
                          icon: seller
                              ? Icons.list_alt
                              : Icons.handshake_outlined,
                        ),
                        _ProfileStat(
                          label: context.clac(
                            seller ? 'Monthly kg' : 'Total kg',
                          ),
                          value: '${formatValue(weight)} kg',
                          icon: Icons.scale_outlined,
                        ),
                      ],
                      _ProfileStat(
                        label: context.clac('CO₂ Saved'),
                        value: '${formatValue(data['carbon_saved_kg'])} kg',
                        icon: Icons.eco_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Eyebrow(context.clac('MY ACTIVITIES')),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    EmptyStateMobile(
                      title: context.clac('No activity yet'),
                      body: context.clac(
                        collector
                            ? 'Your collection points and exchanges will appear here.'
                            : 'Transactions will appear here.',
                      ),
                    )
                  else
                    ...recent.map((item) {
                      final date = DateTime.tryParse(
                        item['created_at']?.toString() ?? '',
                      );
                      final when = date == null
                          ? ''
                          : MaterialLocalizations.of(
                              context,
                            ).formatShortDate(date);
                      return _RecentActivityItem(
                        title:
                            '${materialLabel(item['waste_type'])} · ${context.clac(item['status']?.toString() ?? 'pending')}',
                        time: when,
                        icon: item['status'] == 'completed'
                            ? Icons.check_circle_outline
                            : Icons.recycling_outlined,
                      );
                    }),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit),
            label: Text(context.clac('Edit Profile')),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    child: Column(
      children: [
        Icon(icon, color: pine, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          label,
          style: const TextStyle(color: muted, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _RecentActivityItem extends StatelessWidget {
  const _RecentActivityItem({
    required this.title,
    required this.time,
    required this.icon,
  });
  final String title;
  final String time;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: pine),
      title: Text(title),
      trailing: Text(time, style: const TextStyle(color: muted, fontSize: 11)),
    ),
  );
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController name;
  late final TextEditingController company;
  late final TextEditingController phone;
  late final TextEditingController photoUrl;
  late final TextEditingController latitude;
  late final TextEditingController longitude;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.user['name']?.toString());
    company = TextEditingController(
      text: widget.user['company_name']?.toString(),
    );
    phone = TextEditingController(text: widget.user['phone']?.toString());
    photoUrl = TextEditingController(
      text: widget.user['profile_photo']?.toString(),
    );
    latitude = TextEditingController(text: widget.user['lat']?.toString());
    longitude = TextEditingController(text: widget.user['lng']?.toString());
  }

  @override
  void dispose() {
    name.dispose();
    company.dispose();
    phone.dispose();
    photoUrl.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final data = <String, dynamic>{
      'name': name.text.trim(),
      'company_name': company.text.trim(),
      'phone': phone.text.trim(),
      'profile_photo': photoUrl.text.trim(),
    };
    if (widget.user['role'] == 'processor') {
      final lat = double.tryParse(latitude.text);
      final lng = double.tryParse(longitude.text);
      if (lat == null ||
          lng == null ||
          lat < 30 ||
          lat > 38.5 ||
          lng < 7 ||
          lng > 12.5) {
        setState(
          () => error = context.clac('Enter valid coordinates inside Tunisia.'),
        );
        return;
      }
      data['lat'] = lat;
      data['lng'] = lng;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await widget.api.updateProfile(data);
      if (mounted) Navigator.pop(context, saved);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.clac('Edit Profile'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: context.clac('Full Name')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: company,
              decoration: InputDecoration(labelText: context.clac('Company')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              decoration: InputDecoration(labelText: context.clac('Phone')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: photoUrl,
              decoration: InputDecoration(
                labelText: context.clac('Profile Photo URL'),
              ),
            ),
            if (widget.user['role'] == 'processor') ...[
              const SizedBox(height: 12),
              Text(
                context.clac(
                  'Business location (use a precise site pin, not the governorate center)',
                ),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.clac('Latitude'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.clac('Longitude'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(
                saving ? context.clac('Saving…') : context.clac('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
