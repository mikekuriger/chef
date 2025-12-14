// screens/help_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';


class HelpScreen extends StatelessWidget {
  final VoidCallback? onDone;
  
  const HelpScreen({super.key, this.onDone});

  // Helper method to open email app
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'zentha.labs@gmail.com',
      queryParameters: {
        'subject': 'Help with AI-Chef App',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      debugPrint('Could not launch email app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "AI-Chef Help",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Learn how to use AI-Chef features",
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.headerSubtitle
              ),
            ),
          ],
        ),
        // back button
        backgroundColor: AppColors.purple950,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            onDone?.call();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Getting Started Section
            _buildSection(
              title: 'Getting Started',
              icon: Icons.start,
              content: 'AI-Chef is your personal AI cooking assistant. Generate personalized recipes, meal plans, and cooking tips based on your ingredients, preferences, and dietary needs.',
            ),
            
            // Recipe Generation Section
            _buildSection(
              title: 'Recipe Generation',
              icon: Icons.restaurant,
              content: 'To generate a recipe:\n\n'
                '• Tap the "Add Recipe" button in the navigation bar\n'
                '• Describe your available ingredients, cuisine type, dietary preferences, or meal ideas\n'
                '• Tap "Generate Recipe" to get your personalized recipe with instructions\n'
            ),
            
            // Recipe Journal Section
            _buildSection(
              title: 'Recipe Journal',
              icon: Icons.auto_stories_rounded,
              content: 'Your recipe journal stores all your generated recipes:\n\n'
                '• Access it through the "My Recipes" tab in the navigation bar\n'
                '• View your recipes chronologically\n'
                '• Tap on any entry to see the full recipe and image\n'
                '• Edit or delete recipes as needed\n'
                '• Coming soon: Categories, Tags, and Search help you find recipes quickly',
            ),
            
            // Dietary Preferences Section
            _buildSection(
              title: 'Dietary Preferences\n (coming soon)',
              icon: Icons.favorite,
              content: 'Set your dietary preferences to get better recipe suggestions:\n\n'
                '• Access through the hamburger menu → Dietary Preferences\n'
                '• Add preferences like vegetarian, vegan, gluten-free, allergies, etc.\n'
                '• These preferences will be considered in your recipe generations\n'
                '• Helps tailor recipes to your needs and restrictions',
            ),
            
            // Managing Your Account Section
            _buildSection(
              title: 'Managing Your Account',
              icon: Icons.manage_accounts,
              content: 'Access account profile and settings through the hamburger menu:\n\n'
                '• View and edit your profile information\n'
                // '• Manage your subscription\n'
                // '• Enable or disable features\n'
                // '• Update your password\n'
                // '• Log out of your account\n'
                '• Delete your account',
            ),
            
            // Recipe Credits & Subscriptions Section
            // _buildSection(
            //   title: 'Credits & Subscriptions',
            //   icon: Icons.stars,
            //   content: 'Understanding your recipe credits:\n\n'
            //     '• Free users get 2 recipe generations per week\n'
            //     '• Pro subscribers get unlimited recipe generations\n'
            //     '• Upgrade through the hamburger menu → Subscription\n',
            // ),
            
            // Contact Section
            _buildSection(
              title: 'Contact Support',
              icon: Icons.contact_support,
              content: 'Need help with AI-Chef? Contact us!\n\n'
                '• Email: zentha.labs@gmail.com\n'
                '• Please include your email address and a detailed description of any issues\n'
                '• You will normally get a response within 24 hours',
              hasButton: true,
              buttonText: 'Email Support',
              onButtonPressed: _launchEmail,
            ),
            
            // Version Information and EULA
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30), // distance from screen bottom
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AI-Chef v1.0.0+1\n© 2025 Michael Kuriger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color.fromARGB(200, 122, 209, 255),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 0),              // space between version and EULA
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(
                              'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')),
                          child: const Text(
                            'Terms of Use',
                            style: TextStyle(
                              color: Color.fromARGB(255, 122, 209, 255),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '|',
                          style: TextStyle(
                            color: Color.fromARGB(200, 122, 209, 255),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(
                              'https://dreamr-us-west-01.zentha.me/static/privacy.html')),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Color.fromARGB(255, 122, 209, 255),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build each section
  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
    bool hasButton = false,
    String buttonText = '',
    VoidCallback? onButtonPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),   // Spacing between sections
      decoration: BoxDecoration(
        color: AppColors.purple950,              // Dark purple background
        borderRadius: BorderRadius.circular(12),   // Bottom corners rounded
        border: Border.all(
          color: const Color(0xFF82D9FF), // pick your border color
          width: 1.0,                     // border width
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 130, 217, 255).withValues(alpha: 0.5), // Shadow color with opacity
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(16),    // Header thickness
            decoration: BoxDecoration(
              color: AppColors.purple800,       // lighter purple for header
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),     // Top corners rounded
                topRight: Radius.circular(12),    // Top corners rounded
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,  // Icon color in headers
                  size: 24,
                ),
                const SizedBox(width: 12),  // Spacing between icon and title
                Text(
                  title,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),  // Title color in headers
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Section content
          Padding(
            padding: const EdgeInsets.all(16),  // 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,   // Content text color
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                
                if (hasButton) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 255, 96, 96),  // Red button color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}