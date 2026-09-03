import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/custom_dropdown.dart';
import 'dashboard_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});
  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameCtrl = TextEditingController();
  String _language = 'English';
  bool _loading = false;

  // NOTE: kept as language NAMES (not translated) since this list is sent
  // to the backend as-is and also drives ApiService.setupUsername(language: ...).
  // Extended to match the same 7 languages now offered in Settings.
  final _languages = const ['English', 'Hindi', 'Hinglish', 'Tamil', 'Bengali', 'Marathi', 'Urdu'];

  @override
  void initState() {
    super.initState();
    _prefillSuggestedUsername();
  }

  void _prefillSuggestedUsername() {
    final user = context.read<AuthProvider>().user ?? {};
    String base = (user['name'] ?? '').toString().trim();
    if (base.isEmpty) {
      final email = (user['email'] ?? '').toString();
      base = email.contains('@') ? email.split('@').first : 'creator';
    }
    base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.length < 3) base = 'creator';
    if (base.length > 15) base = base.substring(0, 15);
    final suffix = (DateTime.now().millisecondsSinceEpoch % 900 + 100).toString();
    _usernameCtrl.text = '${base}_$suffix';
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim().replaceFirst('@', '');
    if (username.length < 3) {
      showToast(context, context.tr('username_min_length_error'), isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().setupUsername(username: username, language: _language);
      if (!mounted) return;
      await _showWelcomeFlow();
    } catch (e) {
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReferralDialog() async {
    final referralCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(context.tr('referral_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('referral_dialog_body')),
              const SizedBox(height: 14),
              TextField(
                controller: referralCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'e.g. 102458XK9F2'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: Text(context.tr('skip')),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final code = referralCtrl.text.trim();
                      if (code.isEmpty) {
                        Navigator.pop(dialogContext);
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final res = await ApiService.instance.applyReferralCode(code);
                        if (mounted) showToast(context, res['message'] ?? context.tr('referral_applied'), isSuccess: true);
                      } catch (e) {
                        if (mounted) showApiError(context, e);
                      } finally {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.tr('apply')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWelcomeFlow() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.celebration_rounded, color: AppColors.purple, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr('welcome_title'))),
        ]),
        content: Text(context.tr('welcome_body')),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('lets_go'))),
        ],
      ),
    );
    if (!mounted) return;

    await _showReferralDialog();
    if (!mounted) return;

    // ⚠️ POP-UP CLEANUP: the auto-triggered "Connect YouTube now?" dialog +
    // immediate OAuth launch was removed from here. Social OAuth connect
    // flows now live exclusively in profile_screen.dart (see
    // _connectYoutube/_connectMeta there) via static ListTile-style cards
    // the user opens on their own — never auto-popped right after signup.
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final avatar = auth.user?['avatar'];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(context.tr('setup_profile_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(gradient: AppColors.gradient, shape: BoxShape.circle),
                  child: avatar != null && avatar.toString().isNotEmpty
                      ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                      : const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 36)),
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr('username_label'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
              const SizedBox(height: 4),
              Text(context.tr('username_suggested_hint'), style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(hintText: '@tech_creator', prefixIcon: Icon(Icons.alternate_email_rounded, size: 18)),
              ),
              const SizedBox(height: 16),
              Text(context.tr('select_language_label'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
              const SizedBox(height: 6),
              CustomDropdown<String>(
                value: _language,
                items: _languages,
                labelBuilder: (l) => l,
                onChanged: (v) => setState(() => _language = v ?? 'English'),
                prefixIcon: const Icon(Icons.language_rounded, size: 18, color: AppColors.purple),
              ),
              const SizedBox(height: 30),
              GradientButton(label: context.tr('continue_btn'), loading: _loading, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}