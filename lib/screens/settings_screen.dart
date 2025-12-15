// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<int> refreshTrigger;
  final VoidCallback? onDone;
  const SettingsScreen({super.key, required this.refreshTrigger, this.onDone});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableAudio = false;
  bool _showRecipeStats = true;  // New preference

  bool _loading = true;
  // final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // final enabled = await _notificationService.getNotificationSetting();
      // final time = await _notificationService.getNotificationTime();
      
      // This would come from API in a real app, but for now we're just using shared prefs
      final prefs = await SharedPreferences.getInstance();
      final audioEnabled = prefs.getBool('enable_audio') ?? false;
      final showRecipeStats = prefs.getBool('show_recipe_stats') ?? true;
      final showRecipeCalendar = prefs.getBool('show_recipe_calendar') ?? true;
      
      setState(() {
        // _enableNotifications = enabled;
        // _notificationTime = time;
        _enableAudio = audioEnabled;
        _showRecipeStats = showRecipeStats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load settings: $e');
      setState(() => _loading = false);
    }
  }

  // Save recipe stats visibility setting
  Future<void> _saveRecipeStatsVisibility(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_recipe_stats', value);
      widget.refreshTrigger.value++;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recipe stats visibility setting saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to save recipe stats visibility setting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save recipe stats visibility setting')),
      );
    }
  }

  // Save recipe calendar visibility setting
  Future<void> _saveRecipeCalendarVisibility(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_recipe_calendar', value);
      widget.refreshTrigger.value++;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recipe calendar visibility setting saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to save recipe calendar visibility setting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save recipe calendar visibility setting')),
      );
    }
  }

  // Save a specific setting immediately
  Future<void> _saveAudioSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_audio', value);
      widget.refreshTrigger.value++;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Audio setting saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to save audio setting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save audio setting')),
      );
    }
  }

  void _showThemeSelectionDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.purple950,
          title: const Text(
            'Choose Theme',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: themeProvider.availableThemes.map((theme) {
              final themeColors = ThemeColors.getThemeColors(theme);
              final isSelected = themeProvider.currentTheme == theme;

              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: themeColors.purple600,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                title: Text(
                  themeColors.displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  themeProvider.setTheme(theme);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Theme changed to ${themeColors.displayName}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Settings card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.purple950,        // Settings card background color
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF82D9FF), // pick your border color
                width: .5,  
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 173, 114, 255),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'User Preferences',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Audio toggle
                SwitchListTile(
                  title: Text(
                    _enableAudio ? "Audio Enabled" : "Audio Disabled",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Play voice prompts when recording recipes",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: _enableAudio,
                  onChanged: (val) {
                    setState(() => _enableAudio = val);
                    _saveAudioSetting(val);
                  },
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white30,
                ),

                // Theme selection
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    final currentThemeColors = ThemeColors.getThemeColors(themeProvider.currentTheme);
                    return ListTile(
                      title: const Text(
                        "App Theme",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "Current: ${currentThemeColors.displayName}",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: currentThemeColors.purple600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: _showThemeSelectionDialog,
                    );
                  },
                ),
                
                  // Recipe Journal Stats Visibility toggle
                  SwitchListTile(
                    title: Text(
                      _showRecipeStats ? "Recipe Stats Visible" : "Recipe Stats Hidden",
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Show statistics section in Recipe Journal",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    value: _showRecipeStats,
                    onChanged: (val) {
                      setState(() => _showRecipeStats = val);
                      _saveRecipeStatsVisibility(val);
                    },
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white30,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple900,     // Settings Screen background color
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Chef Settings",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Customize your app experience",
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.headerSubtitle,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.purple950,     // AppBar background color
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _loading ? _buildLoadingWidget() : _buildSettingsContent(),
    );
  }
}