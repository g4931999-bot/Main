import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// Extracted out of diamond_store_screen.dart into its own screen so gift
// code redemption isn't tied to the diamond purchase flow anymore — same
// logic, same API call (ApiService.redeemGiftCode), just living on its own
// route now (see profile_screen.dart, added right below "Buy Diamonds").
class GiftCodeScreen extends StatefulWidget {
  const GiftCodeScreen({super.key});
  @override
  State<GiftCodeScreen> createState() => _GiftCodeScreenState();
}

class _GiftCodeScreenState extends State<GiftCodeScreen> {
  final _giftCodeCtrl = TextEditingController();
  bool _redeemingGiftCode = false;

  @override
  void dispose() {
    _giftCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeemGiftCode() async {
    final code = _giftCodeCtrl.text.trim();
    if (code.isEmpty) {
      showToast(context, 'Enter a gift code first', isError: true);
      return;
    }
    setState(() => _redeemingGiftCode = true);
    try {
      final res = await ApiService.instance.redeemGiftCode(code);
      _giftCodeCtrl.clear();
      if (mounted) showToast(context, res['message'] ?? 'Gift code redeemed!', isSuccess: true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _redeemingGiftCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gift Code')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.surfaces.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.card_giftcard_rounded, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  const Text('Have a Gift Code?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Got a gift code from a giveaway, promo, or a friend? Enter it below to instantly claim your diamonds.',
                  style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _giftCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'Enter code'),
                      onSubmitted: (_) => _redeemGiftCode(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _redeemingGiftCode ? null : _redeemGiftCode,
                      child: _redeemingGiftCode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Redeem'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
