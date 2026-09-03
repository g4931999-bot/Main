import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../providers/language_provider.dart';

/// Checks the backend for whether the weekly Rate Us prompt should be shown,
/// and if so, presents it as a bottom sheet. Safe to call after any screen
/// load — silently does nothing if it's not time yet or the check fails.
Future<void> maybeShowRateUsPopup(BuildContext context) async {
  try {
    final res = await ApiService.instance.getRatingStatus();
    if (res['shouldShow'] != true) return;
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // ⚠️ FIX (overflow): RateUsBody has a star row + AI-suggested review
      // TextField + email field + submit button — tall enough, especially
      // with the keyboard open for the review field, to overflow a
      // non-scrollable modal ("BOTTOM OVERFLOWED BY N PIXELS"). Wrapped in
      // a SingleChildScrollView with keyboard-aware bottom padding, same
      // pattern already used correctly by every other bottom sheet in the
      // app (profile_screen.dart, settings_screen.dart, upload_screen.dart).
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: const RateUsBody(isPopup: true),
        ),
      ),
    );
  } catch (_) {
    // Non-critical — never let a failed status check disrupt the app.
  }
}

class RateUsScreen extends StatelessWidget {
  const RateUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('rate_us_title'))),
      body: const RateUsBody(isPopup: false),
    );
  }
}

/// Shared form used both by the full Rate Us page and the weekly popup —
/// same UI in both places, as requested.
class RateUsBody extends StatefulWidget {
  final bool isPopup;
  const RateUsBody({super.key, required this.isPopup});

  @override
  State<RateUsBody> createState() => _RateUsBodyState();
}

class _RateUsBodyState extends State<RateUsBody> {
  int _stars = 0;
  bool _loadingSuggestion = false;
  bool _submitting = false;
  bool _reviewManuallyEdited = false;
  bool _loadingExisting = true;
  Map<String, dynamic>? _savedRating;

  late final TextEditingController _reviewCtrl;
  late final TextEditingController _emailCtrl;

  // Values are translation KEYS now (not display text) — resolved via
  // context.tr() in build() so the star label follows the selected language.
  static const _starLabelKeys = {1: 'star_poor', 2: 'star_fair', 3: 'star_good', 4: 'star_great', 5: 'star_excellent'};

  @override
  void initState() {
    super.initState();
    _reviewCtrl = TextEditingController();
    final user = context.read<AuthProvider>().user ?? {};
    _emailCtrl = TextEditingController(text: user['email'] ?? '');
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final res = await ApiService.instance.getMyRating();
      final rating = res['rating'];
      if (rating != null && mounted) {
        setState(() => _savedRating = rating);
      }
    } catch (_) {
      // If this fails we just show the empty form — not critical.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectStars(int stars) async {
    setState(() => _stars = stars);
    if (_reviewManuallyEdited) return;
    setState(() => _loadingSuggestion = true);
    try {
      final res = await ApiService.instance.suggestRatingReview(stars);
      if (mounted && !_reviewManuallyEdited) {
        setState(() => _reviewCtrl.text = res['reviewText'] ?? '');
      }
    } catch (_) {
      // AI suggestion failing shouldn't block the user from writing their own.
    } finally {
      if (mounted) setState(() => _loadingSuggestion = false);
    }
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      showToast(context, context.tr('select_star_first_error'), isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiService.instance.submitRating(
        stars: _stars,
        reviewText: _reviewCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _savedRating = res['rating']);
      showToast(context, context.tr('thanks_for_feedback'), isSuccess: true);
      if (widget.isPopup) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    try {
      await ApiService.instance.dismissRating();
    } catch (_) {
      // Non-critical — worst case the popup reappears a bit sooner than intended.
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
      );
    }

    if (_savedRating != null) {
      return _buildSavedCard(_savedRating!);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, widget.isPopup ? 12 : 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isPopup)
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: context.surfaces.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(gradient: AppColors.gradient, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.star_rounded, color: Colors.white, size: 30)),
          ),
          const SizedBox(height: 14),
          Text(context.tr('enjoying_app'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(context.tr('let_us_know'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled = starIndex <= _stars;
              return GestureDetector(
                onTap: () => _selectStars(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? AppColors.diamond : context.surfaces.textDim,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          // Shows what the selected star count means, so a plain number
          // ("4 stars") reads as an actual sentiment ("Great").
          if (_stars > 0) ...[
            const SizedBox(height: 8),
            Text(context.tr(_starLabelKeys[_stars] ?? ''), style: const TextStyle(color: AppColors.diamond, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 20),

          Row(children: [
            Text(context.tr('your_review'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
            const SizedBox(width: 8),
            if (_loadingSuggestion) ...[
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)),
              const SizedBox(width: 6),
              Text(context.tr('ai_writing_suggestion'), style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
            ],
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _reviewCtrl,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => _reviewManuallyEdited = true,
            decoration: InputDecoration(hintText: context.tr('review_hint')),
          ),
          const SizedBox(height: 6),

          Text(context.tr('your_email'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined, size: 18)),
          ),
          const SizedBox(height: 24),

          GradientButton(label: context.tr('save_rating'), loading: _submitting, onPressed: _submit),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _skip,
              child: Text(context.tr('skip'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCard(Map<String, dynamic> rating) {
    final stars = rating['stars'] ?? 0;
    final review = rating['reviewText'] ?? '';
    final email = rating['email'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isPopup)
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: context.surfaces.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 40),
          const SizedBox(height: 12),
          Text(context.tr('thanks_for_feedback'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaces.card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.email_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (i) => Icon(
                        i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppColors.diamond,
                        size: 20,
                      )),
                ),
                const SizedBox(height: 10),
                Text(review, style: TextStyle(color: context.surfaces.textDim, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isPopup)
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.tr('close'))),
        ],
      ),
    );
  }
}