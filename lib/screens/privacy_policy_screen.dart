// screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/theme/colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _subTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple950,
      appBar: AppBar(
        backgroundColor: AppColors.purple950,
        elevation: 4,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy – AI Chef',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Effective Date: April 30, 2025',
              style: TextStyle(
                color: Color(0xFFC9B4FF),
                fontSize: 12,
              ),
            ),

            _sectionTitle('1. Information We Collect'),
            _paragraph(
              'We collect the minimum information needed to create and operate your '
              'AI Chef account and provide recipe generation features.',
            ),

            _subTitle('Account Information'),
            _bullet('First name'),
            _bullet('Last name'),
            _bullet('Email address'),
            _bullet('Login credentials (password stored as a secure hash)'),
            _bullet(
              'Social login identifiers (such as your Apple user ID or Google '
              'account ID and email, if you choose to sign in with those services)',
            ),
            _bullet('Device timezone (automatically provided by your device)'),
            // _bullet(
            //   'Optional profile details you choose to provide, such as birthdate and gender',
            // ),

            _subTitle('Recipe Content'),
            _bullet('Recipes you submit (text)'),
            _bullet(
              'AI-generated recipes',
            ),

            _subTitle('Technical and Usage Information'),
            _bullet(
              'IP address and basic device information (e.g., operating system, app version) '
              'captured in server logs',
            ),
            _bullet('Timestamps of logins, requests, and errors'),
            _paragraph(
              'We use this information to operate, secure, and diagnose issues with the service. '
              'We do not sell your personal information. We do not share your data with third parties '
              'for advertising or marketing.',
            ),

            _sectionTitle('2. Location Data'),
            _paragraph(
              'AI Chef does not access or collect GPS or precise location data.',
            ),

            _sectionTitle('3. How We Use Your Information'),
            _paragraph('We use the information we collect to:'),
            _bullet('Create and maintain your account'),
            _bullet('Store and display your recipe journal entries'),
            _bullet('Manage subscriptions and verify purchases through Apple and Google'),
            _bullet('Maintain and improve app performance, security, and reliability'),
            _paragraph('We do not use your data for targeted advertising.'),

            _sectionTitle('4. Third-Party Services'),
            _paragraph('AI Chef may interact with the following third-party services:'),
            _bullet(
              'OpenAI and other AI providers – Used to analyze recipes and generate text '
              'responses based on the content you submit. Your recipe text or prompts '
              'derived from it are sent to these providers so they can generate responses.',
            ),
            _bullet(
              'Apple (App Store) and Google (Google Play) – Handle app distribution, subscription '
              'management, and payment processing.',
            ),
            _bullet(
              'Hosting and infrastructure providers – Used to host our servers and databases and '
              'deliver content securely over HTTPS.',
            ),
            _paragraph(
              'If you choose to sign in with Apple or Google, those providers may share limited '
              'information with us (such as your name and email address or a private relay email). '
              'We do not receive your Apple or Google passwords. Your use of those services is also '
              'governed by their respective privacy policies.',
            ),
            _paragraph(
              'AI Chef contains no third-party advertising SDKs and does not use analytics tools that '
              'track your activity across other apps or websites.',
            ),

            _sectionTitle('5. Local Storage and Offline Use'),
            _paragraph(
              'Recipe data (including AI responses) may be cached locally on your device '
              'to support better performance and offline access.',
            ),
            _paragraph(
              'You can remove this local data by clearing the app’s storage/cache in your device '
              'settings or by uninstalling the app. Server-side data is not automatically deleted when '
              'you uninstall; see “Data Retention and Deletion” below.',
            ),

            _sectionTitle('6. Data Retention and Deletion'),
            _paragraph(
              'Your recipes, AI responses, and account data are stored on our servers until you '
              'delete them or delete your account.',
            ),
            _bullet('You may delete individual recipes from within the app (where supported).'),
            _bullet(
              'You may request full account and data deletion at any time by contacting us at '
              'the email address below.',
            ),
            _paragraph(
              'Some limited information (such as server logs or purchase records) may be retained '
              'for a reasonable period as required for security, legal, or accounting purposes.',
            ),

            _sectionTitle('7. Security'),
            _paragraph(
              'We use industry-standard security measures, including HTTPS encryption and secure '
              'password hashing, to protect your data in transit and at rest.',
            ),
            _paragraph(
              'No method of transmission or storage is 100% secure, but we work to keep your '
              'information reasonably safe and limit access to it.',
            ),

            _sectionTitle('8. Children’s Privacy'),
            _paragraph(
              'AI Chef is not intended for children under the age of 13. We do not knowingly collect '
              'personal information from children under 13.',
            ),
            _paragraph(
              'If you believe we have collected information from a child under 13, please contact '
              'us immediately so we can delete it.',
            ),

            _sectionTitle('9. Changes to This Policy'),
            _paragraph(
              'We may update this Privacy Policy from time to time. If we make significant changes, '
              'we will notify you in the app or via the app store listing.',
            ),
            _paragraph(
              'Your continued use of AI Chef after an update means you accept the revised policy.',
            ),

            _sectionTitle('10. Contact Information'),
            _paragraph('If you have questions or concerns about this Privacy Policy or your data, please contact:'),
            _paragraph('Michael Kuriger'),
            _paragraph('Email: mikekuriger@gmail.com'),
            _paragraph('Social: @mikekuriger'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
