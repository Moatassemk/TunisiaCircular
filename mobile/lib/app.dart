import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/features/auth/auth_screens.dart';
import 'package:clac_mobile/features/auth/splash_screen.dart';
import 'package:clac_mobile/shell/mobile_shell.dart';

class ClacApp extends StatefulWidget {
  const ClacApp({super.key});

  @override
  State<ClacApp> createState() => _ClacAppState();
}

class _ClacAppState extends State<ClacApp> {
  final api = ApiClient();
  Map<String, dynamic>? user;
  String authPage = 'welcome';
  String selectedRole = 'generator';
  bool starting = true;
  bool showSplash = true;
  bool darkMode = false;
  Locale locale = const Locale('en');

  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    api.onSessionExpired = _expireSession;
    // Start the timer after the first frame: on slow (debug) launches the
    // engine can take longer than the splash duration to paint, which would
    // otherwise skip the splash entirely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splashTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted && showSplash) setState(() => showSplash = false);
      });
    });
    restoreSession();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('token');
    final storedUser = preferences.getString('user');
    locale = Locale(preferences.getString('locale') ?? 'en');
    darkMode = preferences.getBool('dark_mode') ?? false;
    if (storedUser != null && (kIsWeb || token != null)) {
      try {
        api.token = kIsWeb ? null : token;
        user = await api.currentUser();
        if (kIsWeb) {
          api.token = null;
          await preferences.remove('token');
        }
        await preferences.setString('user', api.encodeObject(user!));
      } catch (exception) {
        final authRejected =
            exception.toString().contains('Invalid or expired token') ||
            exception.toString().contains('Access token required');
        if (!kIsWeb && !authRejected) {
          // Keep a cached profile available while offline; the next API call
          // will clear this session if the server rejects its token.
          user = api.decodeObject(storedUser);
        } else {
          api.token = null;
          await preferences.remove('token');
          await preferences.remove('user');
        }
      }
    }
    if (mounted) setState(() => starting = false);
  }

  Future<void> signIn(String email, String password) async {
    late Map<String, dynamic> response;
    try {
      response = await api.login(email, password);
    } catch (exception) {
      rethrow;
    }
    if ((!kIsWeb && !response.containsKey('token')) ||
        !response.containsKey('user')) {
      throw Exception('Invalid login response: missing session or user.');
    }
    final preferences = await SharedPreferences.getInstance();
    api.token = response['token']?.toString();
    user = Map<String, dynamic>.from(response['user'] as Map);
    if (!kIsWeb && api.token != null) {
      await preferences.setString('token', api.token!);
    } else {
      await preferences.remove('token');
    }
    await preferences.setString('user', api.encodeObject(user!));
    if (mounted) setState(() => authPage = 'welcome');
  }

  Future<void> register(Map<String, dynamic> data) async {
    await api.register(data);
    await signIn(data['email'] as String, data['password'] as String);
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      try {
        await api.logout();
      } catch (_) {}
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('token');
    await preferences.remove('user');
    api.token = null;
    if (mounted) setState(() => user = null);
  }

  Future<void> _expireSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('token');
    await preferences.remove('user');
    api.token = null;
    user = null;
    authPage = 'login';
    if (kIsWeb) {
      try {
        await api.logout();
      } catch (_) {}
    }
    if (mounted && !starting) setState(() {});
  }

  Future<void> updateLocale(String languageCode) async {
    final next = Locale(languageCode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('locale', languageCode);
    if (mounted) setState(() => locale = next);
  }

  Future<void> updateTheme(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('dark_mode', value);
    if (mounted) setState(() => darkMode = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CLAC',
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppDarkTheme(),
    themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    home: showSplash || starting
        ? const SplashScreen()
        : user == null
        ? buildAuthPage()
        : MobileShell(
            user: user!,
            api: api,
            onSignOut: signOut,
            onLocaleChange: updateLocale,
            onThemeChange: updateTheme,
          ),
  );

  Widget buildAuthPage() {
    if (authPage == 'login') {
      return LoginScreen(
        onSubmit: signIn,
        onBack: () => setState(() => authPage = 'welcome'),
      );
    }
    if (authPage == 'register') {
      return RegisterScreen(
        role: selectedRole,
        onSubmit: register,
        onBack: () => setState(() => authPage = 'welcome'),
      );
    }
    return WelcomeScreen(
      onChooseRole: (role) => setState(() {
        selectedRole = role;
        authPage = 'register';
      }),
      onSignIn: () => setState(() => authPage = 'login'),
    );
  }
}
