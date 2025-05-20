import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/providers/order_provider.dart';
import 'package:medcareapp/screens/splash_screen.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:medcareapp/widgets/provider_initializer.dart';
import 'package:medcareapp/utils/database_reset_helper.dart';
import 'package:medcareapp/screens/home/home_screen.dart';
import 'package:medcareapp/screens/auth/login_screen.dart';
import 'package:medcareapp/utils/shared_prefs_helper.dart';

// Set this to true ONCE to reset the database, then set back to false
const bool FORCE_RESET_DB = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add error logging for debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter error: ${details.exception}');
    print('Stack trace: ${details.stack}');
    FlutterError.presentError(details);
  };

  if (FORCE_RESET_DB) {
    try {
      // Also clear SharedPreferences data for a complete reset
      await SharedPrefsHelper.clearAll();
      await DatabaseResetHelper.forceResetDatabase();
      print('Database and preferences reset successfully');
    } catch (e) {
      print('Failed to reset data: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (context) => MedicineProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: ProviderInitializer(
        child: MaterialApp(
          title: 'MedCare',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            // Additional routes can be added here
          },
        ),
      ),
    );
  }
}
