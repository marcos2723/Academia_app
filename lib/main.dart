import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/firestore_service.dart';
import 'utils/theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/aluno/aluno_home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  await ThemeController.instance.load();
  runApp(const AcademiaApp());
}

/// Paleta do app (claro e escuro), baseada no turquesa da marca.
/// Claro: fundo off-white frio, cartões brancos com borda e sombra suaves,
/// texto em azul-marinho (slate). Escuro: azul-petróleo bem escuro, cartões
/// um degrau mais claros, texto quase branco.
const Color _kBrandLight = Color(0xFF00B4A2);
const Color _kBrandDark = Color(0xFF2DD4BF);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final page = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  final card = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  final textMain = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  final brand = isDark ? _kBrandDark : _kBrandLight;
  final brandTint = isDark ? const Color(0xFF134E4A) : const Color(0xFFD5F3F0);
  final inputFill = isDark ? const Color(0xFF172033) : const Color(0xFFF1F5F9);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: _kBrandLight,
    brightness: brightness,
  ).copyWith(
    primary: brand,
    onPrimary: const Color(0xFF0F172A),
    primaryContainer: isDark ? const Color(0xFF115E59) : const Color(0xFFCCF1ED),
    onPrimaryContainer: isDark ? const Color(0xFF99F6E4) : const Color(0xFF064E47),
    secondaryContainer: brandTint,
    onSecondaryContainer: textMain,
    surface: page,
    onSurface: textMain,
    onSurfaceVariant: textSecondary,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: isDark ? const Color(0xFF0B1220) : card,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: card,
    surfaceContainerHighest: isDark ? const Color(0xFF273449) : card,
    outline: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
    outlineVariant: border,
    error: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
  );

  OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: page,
    dividerTheme: DividerThemeData(color: border, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: card,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: border)),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: isDark ? 0 : 1,
      shadowColor: const Color(0x0D000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: brandTint,
      selectedIconTheme: IconThemeData(color: brand),
      unselectedIconTheme: IconThemeData(color: textSecondary),
      selectedLabelTextStyle: TextStyle(color: brand, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: textSecondary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brandTint,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? brand : textSecondary),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? brand : textSecondary,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: brand,
      unselectedLabelColor: textSecondary,
      indicatorColor: brand,
      dividerColor: border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      border: inputBorder(border),
      enabledBorder: inputBorder(border),
      focusedBorder: inputBorder(brand, 2),
    ),
  );
}

class AcademiaApp extends StatefulWidget {
  const AcademiaApp({super.key});

  @override
  State<AcademiaApp> createState() => _AcademiaAppState();
}

class _AcademiaAppState extends State<AcademiaApp> {
  // Guardado uma única vez: ao trocar o tema o app é reconstruído, e um
  // stream novo faria o login/painel recarregar do zero.
  late final Stream<User?> _authStream = AuthService().authStateChanges;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Evolui',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeController.instance.mode,
      home: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return _RoleGate(uid: user.uid);
        },
      ),
      ),
    );
  }
}

/// Depois do login, decide se a conta é de um personal ou de um aluno:
/// alunos são reconhecidos por terem um cadastro em `students` apontando
/// o próprio uid em `authUid`. Quem não é aluno é tratado como personal
/// (único outro tipo de usuário do app).
class _RoleGate extends StatefulWidget {
  const _RoleGate({required this.uid});
  final String uid;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  late final _studentFuture = FirestoreService(ownerUid: widget.uid).fetchStudentByAuthUid(widget.uid);

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    return FutureBuilder(
      future: _studentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final isStudent = snapshot.data != null;
        return isStudent ? AlunoHomeShell(authUid: uid) : HomeShell(uid: uid);
      },
    );
  }
}
