import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

import '../../../core/device/device_id_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/feedback_category.dart';
import '../services/feedback_api_service.dart';

class FeedbackScreen extends StatefulWidget {
  final FeedbackApiService? service;
  const FeedbackScreen({super.key, this.service});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final FeedbackApiService _feedbackApiService;
  final DeviceIdService _deviceIdService = DeviceIdService();
  final TextEditingController _messageController = TextEditingController();

  FeedbackCategory _category = FeedbackCategory.technical;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _feedbackApiService = widget.service ?? FeedbackApiService();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations loc, FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.pronunciation:
        return loc.feedbackPronunciation;
      case FeedbackCategory.translation:
        return loc.feedbackTranslation;
      case FeedbackCategory.audioQuality:
        return loc.feedbackAudioQuality;
      case FeedbackCategory.wrongCharacter:
        return loc.feedbackWrongCharacter;
      case FeedbackCategory.wrongWord:
        return loc.feedbackWrongWord;
      case FeedbackCategory.wrongImage:
        return loc.feedbackWrongImage;
      case FeedbackCategory.technical:
        return loc.feedbackTechnical;
      case FeedbackCategory.contentSuggestion:
        return loc.feedbackContentSuggestion;
      case FeedbackCategory.other:
        return loc.feedbackOther;
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final loc = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final message = _messageController.text.trim();

    if (message.isEmpty || message.runes.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? loc.feedbackEmptyMessage
                : languageCode == 'fr'
                ? '5000 caractères maximum.'
                : languageCode == 'ar'
                ? 'الحد الأقصى 5000 حرف.'
                : 'Maximum 5000 characters.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final deviceId = await _deviceIdService.getOrCreateDeviceId();
      final title = _categoryLabel(loc, _category);

      await _feedbackApiService.sendFeedback(
        feedbackType: _category.value,
        title: title,
        message: message,
        deviceId: deviceId,
        appVersion: '1.0.0+1',
        platform: 'android',
        languageCode: languageCode,
      );

      if (!mounted) return;

      _messageController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.feedbackSent)));

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiRequestException && error.statusCode == 429
                ? (languageCode == 'fr'
                      ? 'Trop d’envois. Réessaie dans ${error.retryAfterSeconds ?? 60} s.'
                      : languageCode == 'ar'
                      ? 'حاول مجددًا بعد ${error.retryAfterSeconds ?? 60} ثانية.'
                      : 'Too many submissions. Try again in ${error.retryAfterSeconds ?? 60} s.')
                : loc.feedbackFailed,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.feedback)),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.feedback,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(loc.feedbackSubtitle),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.feedbackCategory,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<FeedbackCategory>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      items: FeedbackCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(loc, category)),
                        );
                      }).toList(),
                      onChanged: _sending
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _category = value;
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      loc.feedbackMessage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _messageController,
                      maxLines: 7,
                      minLines: 5,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: loc.feedbackMessageHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(loc.sendFeedback),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Device ID, language and app version are sent automatically.',
                      style: TextStyle(
                        color: AppColors.mutedWhite,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
