import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/screens/auth/login_screen.dart';
import 'package:medcareapp/screens/home/home_screen.dart';
import 'package:medcareapp/utils/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Wait a bit to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Get auth status and navigate accordingly
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Navigate based on authentication status
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) =>
                  authProvider.isAuthenticated
                      ? const HomeScreen()
                      : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.accentColor],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medication_rounded, size: 100, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'MedCare',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Health Partner',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 48),
              const SpinKitDoubleBounce(color: Colors.white, size: 50.0),
            ],
          ),
        ),
      ),
    );
  }
}
