import 'package:flutter/material.dart';

/// Safe route target used until the corresponding WooCommerce feature screen
/// is connected to its repository. It keeps CMS actions navigable without
/// pretending that product data has already been loaded.
class CommerceRouteDestination extends StatelessWidget {
  const CommerceRouteDestination({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onGoHome,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
              if (onGoHome != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onGoHome,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('العودة للرئيسية'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
