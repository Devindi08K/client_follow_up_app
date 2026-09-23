import 'package:flutter/material.dart';

/// Static in-app privacy policy (GLOBAL_READINESS §1.AB, §2 Phase G5).
/// Replace the placeholder text with your actual reviewed policy before
/// release — this is scaffolding, not legal advice.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What we store', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'We store your business profile, your client contact details '
                    '(name, email, phone), and workflow information such as request '
                    'titles, item names, statuses, and reminder history.',
              ),
              const SizedBox(height: 20),
              Text('What we never store', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'We do not store client documents, uploaded files, or the contents '
                    'of your emails, WhatsApp messages, or phone calls. Communication '
                    'happens entirely in your own email, WhatsApp, and phone apps.',
              ),
              const SizedBox(height: 20),
              Text('Your controls', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'You can export a summary of your data or request account deletion '
                    'at any time from Settings.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}