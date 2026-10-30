import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale_provider.dart';

class AppLanguageTile extends ConsumerWidget {
  const AppLanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final preference = ref.watch(appLanguagePreferenceProvider);
    final current = preference.value ?? AppLanguage.system;
    return ListTile(
      key: const Key('account-language'),
      leading: const Icon(Icons.language),
      title: Text(arabic ? 'اللغة' : 'Language'),
      subtitle: Text(_label(current, arabic)),
      trailing: const Icon(Icons.chevron_right),
      onTap: preference.isLoading
          ? null
          : () async {
              final selected = await showModalBottomSheet<AppLanguage>(
                context: context,
                useSafeArea: true,
                showDragHandle: true,
                builder: (sheet) => SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final language in AppLanguage.values)
                        ListTile(
                          key: Key('app-language-${language.name}'),
                          title: Text(_label(language, arabic)),
                          selected: current == language,
                          trailing: current == language
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(sheet).pop(language),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
              if (selected == null || !context.mounted) return;
              try {
                await ref
                    .read(appLanguagePreferenceProvider.notifier)
                    .select(selected);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      arabic
                          ? 'تعذر حفظ اللغة. حاول مرة أخرى.'
                          : 'Could not save the language. Please try again.',
                    ),
                  ),
                );
              }
            },
    );
  }

  String _label(AppLanguage language, bool arabic) => switch (language) {
    AppLanguage.system => arabic ? 'لغة التليفون' : 'Phone language',
    AppLanguage.ar => 'العربية',
    AppLanguage.en => 'English',
  };
}

