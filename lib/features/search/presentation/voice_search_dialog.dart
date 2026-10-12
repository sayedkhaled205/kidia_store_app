import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../application/voice_search_engine.dart';

Future<void> showVoiceCatalogSearch(BuildContext context, {VoiceSearchEngine? engine}) async {
  final query = await showDialog<String>(context: context, builder: (_) => VoiceSearchDialog(engine: engine ?? PlatformVoiceSearch.instance));
  if (context.mounted && query != null && query.trim().isNotEmpty) {
    context.push('/search?q=${Uri.encodeQueryComponent(query.trim())}');
  }
}

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key, required this.engine});
  final VoiceSearchEngine engine;
  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}
class _VoiceSearchDialogState extends State<VoiceSearchDialog> {
  final _text = TextEditingController();
  bool _started = false, _listening = false, _failed = false;
  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';
  String copy(String ar, String en) => _arabic ? ar : en;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) { _started = true; unawaited(_start()); }
  }
  Future<void> _start() async {
    setState(() { _listening = true; _failed = false; });
    final available = await widget.engine.start(language: Localizations.localeOf(context).languageCode,
      onWords: (words) { if (mounted) setState(() { _text.text = words; }); },
      onError: () { if (mounted) setState(() { _failed = true; _listening = false; }); },
      onDone: () { if (mounted) setState(() { _listening = false; }); },
    );
    if (mounted && !available) setState(() { _failed = true; _listening = false; });
  }
  @override
  void dispose() { unawaited(widget.engine.cancel()); _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(copy('البحث بالصوت', 'Voice search')),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_listening ? Icons.mic : Icons.mic_off, size: 36),
      const SizedBox(height: 12),
      Text(_failed ? copy('البحث بالصوت غير متاح أو إذن الميكروفون مرفوض. يمكنك كتابة البحث.', 'Voice search is unavailable or microphone permission was denied. You can type your search.') : _listening ? copy('قولي اسم المنتج…', 'Say a product name…') : copy('راجعي النص ثم اضغطي بحث', 'Review the text, then search')),
      const SizedBox(height: 12),
      TextField(key: const Key('voice-search-query'), controller: _text, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: copy('البحث', 'Search'))),
    ]),
    actions: [
      TextButton(key: const Key('voice-search-cancel'), onPressed: () => Navigator.pop(context), child: Text(copy('إلغاء', 'Cancel'))),
      if (_listening) TextButton(onPressed: () async { await widget.engine.stop(); if (mounted) setState(() { _listening = false; }); }, child: Text(copy('إيقاف', 'Stop'))),
      FilledButton(key: const Key('voice-search-submit'), onPressed: _text.text.trim().isEmpty ? null : () => Navigator.pop(context, _text.text.trim()), child: Text(copy('بحث', 'Search'))),
    ],
  );
}
