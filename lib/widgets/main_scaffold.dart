// widgets/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/theme/theme_provider.dart';
import 'package:chef/screens/dashboard_screen.dart';
import 'package:chef/screens/recipe_journal_screen.dart';
import 'package:chef/screens/recipe_journal_editor_screen.dart';
// import 'package:chef/screens/profile_screen.dart.old';
import 'package:chef/screens/settings_screen.dart';
import 'package:chef/screens/help_screen.dart';
import 'package:chef/screens/pantry_screen.dart';
import 'package:chef/screens/manage_recipes_screen.dart';
import 'package:chef/constants.dart';
import 'package:chef/utils/session_manager.dart';
import 'package:provider/provider.dart';
import 'package:chef/state/pantry_model.dart';

// Refresh triggers for each screen
final ValueNotifier<int> dreamEntryRefreshTrigger = ValueNotifier<int>(0);
final ValueNotifier<int> journalRefreshTrigger = ValueNotifier<int>(0);
// final ValueNotifier<int> galleryRefreshTrigger = ValueNotifier<int>(0);
final ValueNotifier<int> pantryRefreshTrigger = ValueNotifier<int>(0);
final ValueNotifier<int> editorRefreshTrigger = ValueNotifier<int>(0);
final ValueNotifier<int> settingsRefreshTrigger = ValueNotifier<int>(0);


class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;
  bool _navEnabled = true;
  
  Widget _getTitleForIndex(int index) {
    String title;
    switch (index) {
      case 0:
        title = "Add Recipe  🛒";
        break;
      case 1:
        title = "Recipe Journal  📖";
        break;
      case 2:
        title = "My Pantry 🧺";
        break;
      default:
        title = "Recipe";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Your Personal AI-powered Chef",
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.headerSubtitle,
          ),
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure subscription data is loaded and up-to-date
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onBottomNavTapped(int index) {
    // force close keyboard
    FocusScope.of(context).unfocus();

    // Trigger refresh logic based on index
    switch (index) {
      case 0:
        dreamEntryRefreshTrigger.value++;
        break;
      case 1:
        journalRefreshTrigger.value++;
        break;
      case 2:
        pantryRefreshTrigger.value++;
        // keep pantry list fresh on tab switch
        context.read<PantryModel>().refresh();
        break;
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Subscribe so theme changes trigger rebuilds (AppColors are set via ThemeProvider).
    context.watch<ThemeProvider>();

    // IMPORTANT: Don't cache view widget instances.
    // If we keep the exact same Widget objects around, Flutter may skip updating
    // them on rebuild, which prevents theme changes from propagating.
    // Using stable keys preserves state while allowing rebuilds.
    final views = <Widget>[
      DashboardScreen(
        key: const PageStorageKey('tab_dashboard'),
        refreshTrigger: dreamEntryRefreshTrigger,
        onAnalyzingChange: (bool analyzing) {
          setState(() {
            _navEnabled = !analyzing;
          });
        },
      ),
      RecipeJournalScreen(
        key: const PageStorageKey('tab_journal'),
        refreshTrigger: journalRefreshTrigger,
      ),
      PantryScreen(key: const PageStorageKey('tab_pantry')),
      // ProfileScreen(
      //   key: const PageStorageKey('tab_profile'),
      //   refreshTrigger: profileRefreshTrigger,
      //   onDone: () {
      //     setState(() {
      //       _selectedIndex = 1;
      //     });
      //   },
      // ),
    ];
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.purple950,
        elevation: 4,
        automaticallyImplyLeading: false,
        title: _getTitleForIndex(_selectedIndex),
          actions: [
            Builder(
              builder: (btnContext) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () async {
                    // iPad check (compute before await)
                    final isIPad =
                        Theme.of(btnContext).platform == TargetPlatform.iOS &&
                        MediaQuery.of(btnContext).size.shortestSide >= 600;

                    if (isIPad) {
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                      if (!btnContext.mounted) return;
                      if (!mounted) return;
                    }

                    final overlayBox =
                        Overlay.of(btnContext).context.findRenderObject() as RenderBox;
                    final buttonBox = btnContext.findRenderObject() as RenderBox;
                    final pos = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);

                    final route = await showMenu<String>(
                      context: btnContext,
                      color: Colors.grey[850],
                      position: RelativeRect.fromLTRB(
                        pos.dx,
                        pos.dy + buttonBox.size.height,
                        overlayBox.size.width - (pos.dx + buttonBox.size.width),
                        overlayBox.size.height - (pos.dy + buttonBox.size.height),
                      ),
                      items: const [
                        PopupMenuItem(
                          value: '/editor',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_outlined, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Manage Recipes', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),

                        PopupMenuItem(
                          value: '/settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Settings', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: '/help',
                          child: Row(
                            children: [
                              Icon(Icons.help_outline, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Help', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Logout', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (!btnContext.mounted || route == null) return;

                    FocusScope.of(btnContext).unfocus();

                    switch (route) {
                      case '/editor':
                        editorRefreshTrigger.value++;
                        Navigator.push(
                          btnContext,
                          MaterialPageRoute(
                            builder: (_) => ManageRecipesScreen(refreshTrigger: editorRefreshTrigger),
                          ),
                        );
                        break;

                      case '/profile':
                        setState(() {
                          _selectedIndex = 3;
                        });
                        break;

                      case '/settings':
                        Navigator.push(
                          btnContext,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              refreshTrigger: settingsRefreshTrigger,
                            ),
                          ),
                        );
                        break;



                      case '/help':
                        Navigator.push(
                          btnContext,
                          MaterialPageRoute(builder: (_) => const HelpScreen()),
                        );
                        break;

                      case '/login':
                        Navigator.pushNamedAndRemoveUntil(
                          btnContext,
                          '/login',
                          (route) => false,
                        );
                        break;

                      case 'logout':
                        await performLogout(btnContext);
                        break;
                    }
                  },
                );
              },
            ),
          ],



        // actions: [
        //   PopupMenuButton<String>(
        //     icon: const Icon(Icons.menu, color: Colors.white),
        //     color: Colors.grey[850],
        //     // color: AppColors.purple900,
        //     onSelected: (String route) async {
        //       // ✅ force keyboard to close when selecting from menu
        //       FocusScope.of(context).unfocus();
              
        //       switch (route) {
        //         case '/editor':
        //           setState(() {
        //             editorRefreshTrigger.value++;
        //             _selectedIndex = 2; 
        //           });
        //           break;

        //         case '/profile':
        //           setState(() {
        //             _selectedIndex = 3; 
        //           });
        //           break;

        //         case '/settings':
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //               builder: (context) => SettingsScreen(
        //                 refreshTrigger: settingsRefreshTrigger,
        //               ),
        //             ),
        //           );
        //           break;
               
        //         case '/help':
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //               builder: (context) => const HelpScreen(),
        //             ),
        //           );
        //           break;
        //         case '/login':
        //           Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        //           break;
        //         case 'logout':
        //           await performLogout(context);
        //           break;
        //       }
        //     },
        //     itemBuilder: (BuildContext context) => [
        //       const PopupMenuItem(
        //         value: '/editor',
        //         child: Row(
        //           children: [
        //             Icon(Icons.visibility_off_outlined, color: Colors.white),
        //             SizedBox(width: 8),
        //             Text('Hide/Delete', style: TextStyle(color: Colors.white)),
        //           ],
        //         ),
        //       ),
              
        //       const PopupMenuItem(
        //         value: '/settings',
        //         child: Row(
        //           children: [
        //             Icon(Icons.settings_outlined, color: Colors.white),
        //             SizedBox(width: 8),
        //             Text('Settings', style: TextStyle(color: Colors.white)),
        //           ],
        //         ),
        //       ),

        //       const PopupMenuItem(
        //         value: '/help',
        //         child: Row(
        //           children: [
        //             Icon(Icons.help_outline, color: Colors.white),
        //             SizedBox(width: 8),
        //             Text('Help', style: TextStyle(color: Colors.white)),
        //           ],
        //         ),
        //       ),
        //       const PopupMenuItem(
        //         value: 'logout',
        //         child: Row(
        //           children: [
        //             Icon(Icons.logout, color: Colors.white),
        //             SizedBox(width: 8),
        //             Text('Logout', style: TextStyle(color: Colors.white)),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ],
      ),
      // body: widget.body,
      body: IndexedStack(
        index: _selectedIndex,
        children: views,
      ),
      bottomNavigationBar: (_selectedIndex == 3 || !_navEnabled)
    ? null // hide nav on profile page OR when analyzing
    : BottomNavigationBar(
        currentIndex: (_selectedIndex == 3) ? 1 : _selectedIndex.clamp(0, 2),
        onTap: _onBottomNavTapped,
        unselectedItemColor: Colors.white70,
        selectedItemColor: Colors.white,
        backgroundColor: AppColors.purple950,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        elevation: 8,
        items: [
          _buildNavItem(
            // icon: Icons.psychology_alt,
            icon: Icons.restaurant_sharp,
            label: 'Add Recipe',
            index: 0,
          ),
          _buildNavItem(
            // icon: Icons.auto_stories_rounded,
            // icon: Icons.fastfood,
            icon: Icons.menu_book,
            label: 'My Recipes',
            index: 1,
          ),
          _buildNavItem(
            icon: Icons.kitchen_outlined,
            label: 'My Pantry',
            index: 2,
          ),
        ],
      ),
    );
  }
  
  // Custom navigation item with dynamic size based on selection state
  BottomNavigationBarItem _buildNavItem({
    required IconData icon, 
    required String label, 
    required int index
  }) {
    
    // Calculate current index for comparison (handle the special case for index 3)
    final currentIdx = (_selectedIndex == 3) ? 1 : _selectedIndex.clamp(0, 2);
    final isSelected = currentIdx == index;
    
    
    // Default navigation item for all other cases
    return BottomNavigationBarItem(
      icon: Container(
        margin: const EdgeInsets.only(bottom: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            icon,
            size: isSelected ? 25.0 : 20.0, // Selected icon is larger
          ),
        ),
      ),
      activeIcon: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.purple800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 25.0,
          color: Colors.white,
        ),
      ),
      label: label,
    );
  }
}

