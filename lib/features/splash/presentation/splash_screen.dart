import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/common/app_network_image.dart';
import '../domain/splash_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.config = const SplashConfig()});
  final SplashConfig config;

  @override
  Widget build(BuildContext context) {
    final String title = config.storeName.isEmpty
        ? AppConfig.storeName
        : config.storeName;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [config.backgroundColor, config.backgroundColorEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: FittedBox(
                // A saved logo frame may be wider than a narrow device, or the
                // preview may be short. Scale the entire composition uniformly.
                fit: BoxFit.scaleDown,
                child: Column(
                  key: const Key('splash-brand-composition'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (config.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          config.imageShape == 'circle'
                              ? config.imageWidth / 2
                              : config.imageShape == 'rounded'
                              ? 18
                              : 0,
                        ),
                        child: AppNetworkImage(
                          imageUrl: config.imageUrl,
                          width: config.imageWidth,
                          height: config.imageHeight,
                          fit: config.imageFit,
                          // Brand artwork must not first appear as a grey product
                          // placeholder. Keep its frame stable while it loads.
                          placeholder: SizedBox(
                            width: config.imageWidth,
                            height: config.imageHeight,
                          ),
                          errorWidget: Icon(
                            Icons.storefront_outlined,
                            color: config.textColor,
                            size: 76,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.storefront_outlined,
                        color: config.textColor,
                        size: 76,
                      ),
                    if (config.showStoreName) ...[
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: config.textColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (config.showLoader) ...[
                      const SizedBox(height: 24),
                      SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: config.loaderColor,
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
