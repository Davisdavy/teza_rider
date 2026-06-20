import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/job_provider.dart';
import 'views/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiService>()),
          update: (context, api, auth) => auth ?? AuthProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiService, JobProvider>(
          create: (context) => JobProvider(context.read<ApiService>()),
          update: (context, api, job) => job ?? JobProvider(api),
        ),
      ],
      child: MaterialApp(
        title: 'Teza Rider Portal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D0E15),
          primaryColor: const Color(0xFF00E676),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E676),
            secondary: Color(0xFF00BFA5),
            surface: Color(0xFF151622),
            error: Color(0xFFFF5252),
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF151622),
            elevation: 0,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
