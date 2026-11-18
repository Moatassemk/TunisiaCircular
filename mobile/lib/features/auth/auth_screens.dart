import 'package:flutter/material.dart';

import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/strings.dart';
import 'package:clac_mobile/shared/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onChooseRole,
    required this.onSignIn,
    super.key,
  });
  final ValueChanged<String> onChooseRole;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          const BrandMark(),
          const SizedBox(height: 12),
          Text(
            'Consommateurs Liés Aux Collecteurs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 34),
          const Eyebrow('JOIN THE MATERIALS NETWORK'),
          const SizedBox(height: 9),
          Text(
            context.clac('How will you use the network?'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            context.clac(
              'Choose the path that fits your organization. You can update your profile later.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 22),
          RoleCard(
            title: context.clac('Sell materials'),
            detail: 'List surplus materials and connect with nearby buyers.',
            icon: Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => onChooseRole('generator'),
          ),
          const SizedBox(height: 12),
          RoleCard(
            title: context.clac('Buy materials'),
            detail: 'Find supply partners for your processing operation.',
            icon: Icons.shopping_bag_outlined,
            color: amber,
            onTap: () => onChooseRole('processor'),
          ),
          const SizedBox(height: 12),
          RoleCard(
            title: context.clac('Manage collection points'),
            detail: context.clac(
              'Run drop-off or pickup points for your collecting society or another region.',
            ),
            icon: Icons.add_location_alt_outlined,
            color: const Color(0xff6956a5),
            onTap: () => onChooseRole('collector'),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: onSignIn,
              child: Text(context.clac('Already a member? Sign in')),
            ),
          ),
        ],
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onSubmit, required this.onBack, super.key});
  final Future<void> Function(String, String) onSubmit;
  final VoidCallback onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(email.text.trim(), password.text);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: context.clac('Welcome back'),
    subtitle: context.clac(
      'Sign in to manage materials and keep them in circulation.',
    ),
    onBack: widget.onBack,
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ErrorBanner(error!),
          TextFormField(
            controller: email,
            decoration: InputDecoration(
              labelText: context.clac('Email address'),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            decoration: InputDecoration(labelText: context.clac('Password')),
            obscureText: true,
            validator: requiredText,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(context.clac(busy ? 'Signing in…' : 'Sign in')),
          ),
        ],
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.role,
    required this.onSubmit,
    required this.onBack,
    super.key,
  });
  final String role;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onBack;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final organization = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final capacity = TextEditingController(text: '5000');
  String governorate = '';
  final acceptedMaterials = <String>{};
  String? error;
  bool busy = false;

  bool get isBuyer => widget.role == 'processor';
  bool get isCollector => widget.role == 'collector';
  @override
  void dispose() {
    name.dispose();
    organization.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (isBuyer && acceptedMaterials.isEmpty) {
      setState(() => error = 'Choose at least one material you want to buy.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'company_name': organization.text.trim(),
      'email': email.text.trim(),
      'password': password.text,
      'phone': phone.text.trim(),
      'gouvernorat': governorate,
      'role': widget.role,
    };
    if (isBuyer) {
      body['accepts_waste_types'] = acceptedMaterials.toList();
      body['max_capacity_kg_per_month'] = int.tryParse(capacity.text) ?? 0;
    }
    try {
      await widget.onSubmit(body);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: isBuyer
        ? 'Buy materials'
        : isCollector
        ? 'Manage collection points'
        : 'Sell materials',
    subtitle: isBuyer
        ? 'Set what your organization accepts and its monthly capacity.'
        : isCollector
        ? 'Register your collecting society and add points anywhere in Tunisia.'
        : 'Create a seller profile and make your materials visible to buyers.',
    onBack: widget.onBack,
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ErrorBanner(error!),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: requiredText,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: organization,
            decoration: const InputDecoration(labelText: 'Organization'),
            validator: requiredText,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: governorate.isEmpty ? null : governorate,
            decoration: const InputDecoration(labelText: 'Governorate'),
            items: governorates
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => governorate = value ?? ''),
            validator: (value) => value == null ? 'Choose a governorate' : null,
          ),
          if (isCollector) ...[
            const SizedBox(height: 12),
            Text(
              context.clac(
                'Your collection points are reviewed by an admin before they appear publicly.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
          if (isBuyer) ...[
            const SizedBox(height: 15),
            const Eyebrow('MATERIALS YOU WANT TO BUY'),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: materials.entries
                  .map(
                    (entry) => FilterChip(
                      label: Text(entry.value),
                      selected: acceptedMaterials.contains(entry.key),
                      onSelected: (selected) => setState(
                        () => selected
                            ? acceptedMaterials.add(entry.key)
                            : acceptedMaterials.remove(entry.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: capacity,
              decoration: const InputDecoration(
                labelText: 'Monthly buying capacity (kg)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Enter a positive capacity'
                  : null,
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email address'),
            keyboardType: TextInputType.emailAddress,
            validator: requiredText,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (value) =>
                (value?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Creating account…' : 'Create account'),
          ),
        ],
      ),
    ),
  );
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onBack,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const BrandMark(compact: true),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Eyebrow(context.clac('MEMBER ACCESS')),
          const SizedBox(height: 6),
          Text(
            context.clac(title),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.clac(subtitle),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}
