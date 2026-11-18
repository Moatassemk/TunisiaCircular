import 'package:flutter/material.dart';
import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:clac_mobile/shared/strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.user,
    required this.api,
    required this.onSignOut,
    required this.onThemeToggle,
    required this.onLocaleChange,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onSignOut;
  final ValueChanged<bool> onThemeToggle;
  final ValueChanged<String> onLocaleChange;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = false;
  bool _themeLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeLoaded) {
      darkMode = Theme.of(context).brightness == Brightness.dark;
      _themeLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ?? theme.cardColor;
    final line = theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Eyebrow(context.clac('ACCOUNT')),
          const SizedBox(height: 10),
          Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(color: line),
            ),
            child: ListTile(
              leading: Icon(
                Icons.person,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                widget.user['name']?.toString() ?? 'User',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                widget.user['email']?.toString() ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Eyebrow(context.clac('PREFERENCES')),
          const SizedBox(height: 10),
          Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(color: line),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(context.clac('Dark Mode')),
                  subtitle: Text(
                    context.clac('Switch between light and dark themes'),
                  ),
                  value: darkMode,
                  secondary: Icon(
                    Icons.dark_mode_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const RoundedRectangleBorder(),
                  onChanged: (value) async {
                    setState(() => darkMode = value);
                    widget.onThemeToggle(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.language_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(context.clac('Language')),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: Localizations.localeOf(context).languageCode,
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(context.clac('English')),
                        ),
                        DropdownMenuItem(
                          value: 'fr',
                          child: Text(context.clac('French')),
                        ),
                        DropdownMenuItem(
                          value: 'ar',
                          child: Text(context.clac('Arabic')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) widget.onLocaleChange(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Eyebrow(context.clac('ABOUT')),
          const SizedBox(height: 10),
          Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(color: line),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(context.clac('App Version')),
                  trailing: Text('1.0.0', style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: Text(context.clac('Sign out')),
            style: FilledButton.styleFrom(
              backgroundColor: dark
                  ? const Color(0xFF3F2521)
                  : const Color(0xFFFAEEEB),
              foregroundColor: dark
                  ? const Color(0xFFFFB4A9)
                  : const Color(0xFF9B5145),
            ),
          ),
        ],
      ),
    );
  }
}
