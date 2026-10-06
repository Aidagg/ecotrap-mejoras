import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/utils/app_colors.dart';
import 'features/files/presentation/pages/api_check_screen.dart';
import 'features/files/presentation/pages/api_config_screen.dart';
import 'features/files/presentation/pages/files_list_screen.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/home/presentation/pages/splash_page.dart';
import 'features/stream/presentation/pages/camera_stream_page.dart';
import 'features/upload/presentation/pages/upload_page.dart';
import 'features/wifi/presentation/bloc/wifi_bloc.dart';
import 'features/wifi/presentation/pages/wifi_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initDependencies();

  runApp(const EcotrapApp());
}

class EcotrapApp extends StatelessWidget {
  const EcotrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoTrap',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        // Colores principales — paleta corporativa EntomoLab
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ),

        // AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),

        // Botones elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 2,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Botones de texto
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // InputDecoration
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.forest),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.primarySurface,
        ),

        // Checkbox
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return null;
          }),
        ),

        // FloatingActionButton
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onPrimary,
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
          contentTextStyle:
              const TextStyle(color: AppColors.onPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          insetPadding: const EdgeInsets.only(
            bottom: 80,
            left: 16,
            right: 16,
          ),
        ),

        // ProgressIndicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.primarySurface,
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.primarySurface,
        ),

        // Typography
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),

        useMaterial3: true,
      ),

      initialRoute: '/splash',

      routes: {
        '/splash': (context) => const SplashPage(),
        '/home': (context) => const HomePage(),
        '/wifi-list': (context) => BlocProvider(
              create: (_) => sl<WiFiBloc>(),
              child: const WiFiListPage(),
            ),
        '/camera-wifi': (context) => BlocProvider(
              create: (_) => sl<WiFiBloc>(),
              child: const WiFiListPage(
                pageTitle: 'Stream',
                connectLabel: 'Conexión a cámara',
                connectRoute: '/camera-stream',
              ),
            ),
        '/camera-stream': (context) => const CameraStreamPage(),
        '/upload': (context) => const UploadPage(),
        '/api-check': (context) => const ApiCheckScreen(),
        '/api-config': (context) => const ApiConfigScreen(),
        '/files-list': (context) => const FilesListScreen(),
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Pagina no encontrada'),
            ),
          ),
        );
      },
    );
  }
}
