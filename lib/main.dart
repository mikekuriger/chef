// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chef/screens/splash_screen.dart';
import 'package:chef/screens/login_screen.dart';
import 'package:chef/screens/register_screen.dart';
import 'package:chef/screens/dashboard_screen.dart';
import 'package:chef/screens/recipe_journal_screen.dart';
import 'package:chef/screens/recipe_journal_editor_screen.dart';
// import 'package:chef/screens/dream_gallery_screen.dart';
import 'package:chef/screens/forgot_password_screen.dart';
import 'package:chef/screens/profile_screen.dart';
// import 'package:chef/screens/subscription_screen.dart.NO';

import 'package:chef/services/dio_client.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/theme/theme_provider.dart';
import 'package:chef/constants.dart';

import 'package:chef/repository/recipe_repository.dart';
import 'package:chef/state/recipe_list_model.dart';
// import 'package:chef/state/subscription_model.dart.NO';
// import 'package:chef/services/notification_service.dart.NO';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await NotificationService().init();
  await DioClient.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<RecipeRepository>(create: (_) => RecipeRepository()),
        ChangeNotifierProvider<RecipeListModel>(
          // includeHidden: true if you want hidden entries in the list model
          create: (ctx) => RecipeListModel(repo: ctx.read<RecipeRepository>())..init(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        // ChangeNotifierProvider<SubscriptionModel>(
          // create: (_) => SubscriptionModel()..init(),
        // ),
      ],
      child: const ReciperApp(),
    ),
  );
}

class ReciperApp extends StatelessWidget {
  const ReciperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Chef',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/dashboard': (context) => DashboardScreen(refreshTrigger: recipeEntryRefreshTrigger),
            '/journal': (context) => RecipeJournalScreen(refreshTrigger: journalRefreshTrigger),
            '/editor': (context) => RecipeJournalEditorScreen(refreshTrigger: journalRefreshTrigger),
            // '/gallery': (context) => RecipeGalleryScreen(refreshTrigger: galleryRefreshTrigger),
            '/image': (context) => const Placeholder(),
            '/profile': (context) => ProfileScreen(refreshTrigger: profileRefreshTrigger),
            '/forgot-password': (_) => const ForgotPasswordScreen(),
            // '/subscription': (context) => const SubscriptionScreen(),
          },
        );
      },
    );
  }
}
