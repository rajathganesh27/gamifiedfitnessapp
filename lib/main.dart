import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'screens/admin_dashboard.dart';
import 'screens/user_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(create: (context) => AuthService(), child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return MaterialApp(
          title: 'FitQuest',
          debugShowCheckedModeBanner: false, // 🔥 Remove Debug Banner
          theme: ThemeData(
            brightness: Brightness.dark, // 🌙 Dark Theme
            primarySwatch: Colors.purple, // 🎨 Primary color
            scaffoldBackgroundColor: Color(0xFF0E0E12), // 🖤 Dark background
            textTheme: GoogleFonts.poppinsTextTheme(
              // 🔥 Modern Font
              Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFD700), // 🟡 Yellow for buttons
                foregroundColor: Colors.black,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
          ),
          home:
              authService.user == null
                  ? LoginScreen()
                  : authService.isAdmin
                  ? AdminDashboard()
                  : UserDashboard(),
        );
      },
    );
  }
}
