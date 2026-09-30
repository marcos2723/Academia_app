import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/aluno/aluno_home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  runApp(const AcademiaApp());
}

/// Antes o app usava tons quase pretos e muito parecidos entre si em
/// TODAS as telas (fundo, AppBar, cards, navegação) — pouca diferença
/// visual entre as camadas, e sem quase nenhuma outra cor além do
/// laranja da marca. Esta paleta é usada em TODO o projeto (não só nas
/// telas de treino/dieta): cinzas bem mais claros e com um degrau maior
/// entre eles (fundo < cartão < navegação < AppBar < diálogo), e ícones
/// de navegação com cores próprias em vez de todos na mesma cor.
const Color _kSeedOrange = Color(0xFFFF7A29);

// Escada de cinzas do app inteiro — cada camada visivelmente mais clara
// que a anterior, em vez do preto quase uniforme de antes.
const Color _kSurface = Color(0xFF29282F);
const Color _kSurfaceContainerLowest = Color(0xFF201F25);
const Color _kSurfaceContainerLow = Color(0xFF322F39);
const Color _kSurfaceContainer = Color(0xFF3C3944);
const Color _kSurfaceContainerHigh = Color(0xFF48454F);
const Color _kSurfaceContainerHighest = Color(0xFF54505C);

ThemeData _buildTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _kSeedOrange,
    brightness: Brightness.dark,
  ).copyWith(
    surface: _kSurface,
    surfaceContainerLowest: _kSurfaceContainerLowest,
    surfaceContainerLow: _kSurfaceContainerLow,
    surfaceContainer: _kSurfaceContainer,
    surfaceContainerHigh: _kSurfaceContainerHigh,
    surfaceContainerHighest: _kSurfaceContainerHighest,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surfaceContainerHigh,
      foregroundColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surfaceContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
    ),
  );
}

class AcademiaApp extends StatelessWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Evolui',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(),
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
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
    );
  }
}

/// Depois do login, decide se a conta é de um personal ou de um aluno:
/// alunos são reconhecidos por terem um cadastro em `students` apontando
/// o próprio uid em `authUid`. Quem não é aluno é tratado como personal
/// (único outro tipo de usuário do app).
class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService(ownerUid: uid);
    return FutureBuilder(
      future: service.fetchStudentByAuthUid(uid),
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
