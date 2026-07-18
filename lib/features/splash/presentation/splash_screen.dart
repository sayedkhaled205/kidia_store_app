import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../domain/splash_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.config = const SplashConfig()});
  final SplashConfig config;

  @override
  Widget build(BuildContext context) {
    final String title = config.storeName.isEmpty ? AppConfig.storeName : config.storeName;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [config.backgroundColor, config.backgroundColorEnd],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.imageUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(config.imageShape == 'circle' ? config.imageWidth / 2 : config.imageShape == 'rounded' ? 18 : 0), child: Image.network(config.imageUrl, width: config.imageWidth, height: config.imageHeight, fit: config.imageFit, errorBuilder: (_, _, _) => const Icon(Icons.storefront_outlined, color: Colors.white, size: 76))) else const Icon(Icons.storefront_outlined, color: Colors.white, size: 76),
              const SizedBox(height: 18),
              if (config.showStoreName) Text(
                title,
                style: TextStyle(
                  color: config.textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              if (config.showLoader) CircularProgressIndicator(color: config.loaderColor),
            ],
          ),
        ),
      ),
    );
  }
}
