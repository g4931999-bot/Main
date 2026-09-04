import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? stats;
  bool loading = true;
  final paymentTabs = const ['pending', 'approved', 'rejected'];
  // ⚠️ CHANGE: "Settings" tab (manual UPI ID / QR code management) removed
  // entirely — since diamond purchases now go through Cashfree's in-app
  // checkout SDK (see diamond_store_screen.dart + backend routes/diamond.js),
  // there is no more UPI ID or QR code for admins to configure. Down to 4 tabs.
  final tabLabels = const ['Pending', 'Approved', 'Rejected', 'Users', 'Gift Codes'];
  final tabIcons = const [
    Icons.hourglass_top_rounded,
    Icons.check_circle_outline_rounded,
    Icons.cancel_outlined,
    Icons.people_alt_outlined,
    Icons.card_giftcard_rounded,
  ];

  // Per-status cache so tabs never show each other's stale data and each
  // tab loads its own data the moment it's actually built.
  final Map<String, List<dynamic>> paymentsByStatus = {
    'pending': [],
    'approved': [],
    'rejected': [],
  };
  final Map<String, bool> paymentsLoadingByStatus = {
    'pending': false,
    'approved': false,
    'rejected': false,
  };
  final Set<String> paymentsLoadedStatuses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (tabLabels[_tabController.index] == 'Users') {
        _loadUsers();
      }
      if (tabLabels[_tabController.index] == 'Gift Codes') {
        _loadGiftCodes();
      }
      setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _giftCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.instance.adminDashboard();
      setState(() => stats = res['stats']);
      await _loadPayments(paymentTabs[_tabController.index], force: true);
    } catch (e) {
      if (mounted) showApiError(context, e);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadPayments(String status, {bool force = false}) async {
    if (!force && paymentsLoadedStatuses.contains(status)) return;
    setState(() => paymentsLoadingByStatus[status] = true);
    try {
      final res = await ApiService.instance.adminPayments(status: status);
      setState(() {
        paymentsByStatus[status] = res['transactions'] ?? [];
        paymentsLoadedStatuses.add(status);
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => paymentsLoadingByStatus[status] = false);
    }
  }

  void _invalidatePayments() => paymentsLoadedStatuses.clear();

  // ---------------- Users tab ----------------
  List<dynamic> users = [];
  bool usersLoading = false;
  final _searchCtrl = TextEditingController();

  Future<void> _loadUsers({String? search}) async {
    setState(() => usersLoading = true);
    try {
      final res = await ApiService.instance.adminUsers(search: search);
      setState(() => users = res['users']);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => usersLoading = false);
    }
  }

  // ---------------- Gift Codes tab ----------------
  List<dynamic> giftCodes = [];
  bool giftCodesLoading = false;
  bool creatingGiftCode = false;
  final _giftCodeCtrl = TextEditingController(); // optional custom code text
  int _newGiftCodeValue = 2;

  Future<void> _loadGiftCodes() async {
    setState(() => giftCodesLoading = true);
    try {
      final res = await ApiService.instance.adminListGiftCodes();
      setState(() => giftCodes = res['giftCodes'] ?? []);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => giftCodesLoading = false);
    }
  }

  Future<void> _createGiftCode() async {
    setState(() => creatingGiftCode = true);
    try {
      final res = await ApiService.instance.adminCreateGiftCode(
        code: _giftCodeCtrl.text.trim().isEmpty ? null : _giftCodeCtrl.text.trim(),
        diamondValue: _newGiftCodeValue,
      );
      _giftCodeCtrl.clear();
      if (mounted) showToast(context, 'Gift code "${res['giftCode']['code']}" created', isSuccess: true);
      await _loadGiftCodes();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => creatingGiftCode = false);
    }
  }

  Future<void> _toggleGiftCodeActive(String id) async {
    try {
      await ApiService.instance.adminToggleGiftCode(id);
      await _loadGiftCodes();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // Signs the user out on every device. Does NOT touch their data — account,
  // diamonds, videos and connections stay exactly as they are.
  Future<void> _forceLogout(String id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Force logout?'),
        content: Text('$label will be signed out on all their devices. Their account and data are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ApiService.instance.forceLogoutUser(id);
      if (mounted) showToast(context, res['message'] ?? 'Logged out', isSuccess: true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _toggleActive(String id, String label) async {
    try {
      final res = await ApiService.instance.toggleUserActive(id);
      if (mounted) showToast(context, res['message'] ?? 'Updated', isSuccess: true);
      _loadUsers(search: _searchCtrl.text.trim());
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // PERMANENTLY deletes the account and all associated data (videos,
  // transactions, notifications). Irreversible. If they sign up again, they
  // get a completely fresh account — new userId, 0 diamonds, everything
  // default, same as any brand new user.
  //
  // Two-step confirm: a warning dialog, then the admin must type the exact
  // username/email to unlock the final Delete button. This is deliberately
  // more friction than force-logout because this action cannot be undone.
  Future<void> _deleteAccount(String id, String label) async {
    final typedCtrl = TextEditingController();
    bool matches = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: AppColors.red, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('Delete account permanently?')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will PERMANENTLY delete $label — their account, diamond balance, videos, and payment history. This cannot be undone.',
              ),
              const SizedBox(height: 6),
              Text(
                'If they sign up again, they start over as a brand new user.',
                style: TextStyle(color: Theme.of(dialogContext).hintColor, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Text('Type "$label" to confirm:', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: typedCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Type exact username/email here'),
                onChanged: (v) => setDialogState(() => matches = v.trim() == label),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
              onPressed: matches ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.instance.deleteUserAccount(id);
      if (mounted) showToast(context, res['message'] ?? 'Account deleted', isSuccess: true);
      _loadUsers(search: _searchCtrl.text.trim());
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  (Color, String) _statusBadge(String status) {
    switch (status) {
      case 'approved': return (AppColors.green, 'approved');
      case 'rejected': return (AppColors.red, 'rejected');
      default: return (AppColors.diamond, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.purple, AppColors.purple.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.surfaces.card2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              splashBorderRadius: BorderRadius.circular(14),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [AppColors.purple, AppColors.purple.withOpacity(0.75)]),
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: context.surfaces.textDim,
              // Icon-only tabs — no more label text to truncate ("Approv…",
              // "Gift Co…"), the tooltip on long-press still carries the
              // full name for accessibility.
              tabs: List.generate(tabLabels.length, (i) {
                return Tab(
                  height: 40,
                  child: Tooltip(
                    message: tabLabels[i],
                    child: Icon(tabIcons[i], size: 19),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: loading
          ? const LoadingView()
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPaymentsList('pending'),
                _buildPaymentsList('approved'),
                _buildPaymentsList('rejected'),
                _buildUsersTab(),
                _buildGiftCodesTab(),
              ],
            ),
    );
  }

  Widget _statsGrid() {
    final cards = [
      ('Total Users', '${stats?['totalUsers'] ?? 0}', Icons.groups_2_outlined, AppColors.purple),
      ('Active Users', '${stats?['activeUsers'] ?? 0}', Icons.bolt_rounded, AppColors.green),
      ('Revenue', '₹${stats?['revenue'] ?? 0}', Icons.currency_rupee_rounded, AppColors.diamond),
      ('Upload Queue', '${stats?['uploadQueue'] ?? 0}', Icons.cloud_upload_outlined, AppColors.red),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // ⚠️ FIX ("BOTTOM OVERFLOWED BY 11 PIXELS"): 1.55 didn't leave enough
      // vertical room for icon-chip + value + label + the 16px padding on
      // all sides, on narrower phone widths — a smaller aspect ratio here
      // means MORE height per card (aspectRatio = width/height), which is
      // what actually fixes it (padding/font tweaks alone don't change the
      // fundamental fact that a fixed aspect ratio was too short).
      childAspectRatio: 1.3,
      children: cards.map((c) {
        final (label, value, icon, color) = c;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surfaces.card2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.surfaces.textDim, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentsList(String status) {
    final list = paymentsByStatus[status] ?? [];
    final isLoading = paymentsLoadingByStatus[status] ?? false;

    if (!paymentsLoadedStatuses.contains(status) && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayments(status));
    }

    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: () => _loadPayments(status, force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _statsGrid(),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${status[0].toUpperCase()}${status.substring(1)} payments',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.surfaces.textDim, letterSpacing: 0.2),
              ),
              const SizedBox(width: 8),
              if (!isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: context.surfaces.card2, borderRadius: BorderRadius.circular(20)),
                  child: Text('${list.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.surfaces.textDim)),
                ),
            ],
          ),
          // Fully automatic now — a background job (routes/diamond.js,
          // autoCheckPendingOrders) re-checks every pending order with
          // Cashfree every 60s and credits diamonds itself the moment it
          // sees PAID, on top of the app's own poll and the webhook. No
          // admin action is ever required; anything genuinely abandoned
          // auto-expires after 24h.
          if (status == 'pending') ...[
            const SizedBox(height: 4),
            Text(
              'Fully automatic — these are re-checked with Cashfree every minute and credited the moment they\'re paid. No action needed.',
              style: TextStyle(color: context.surfaces.textDim, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          if (isLoading && list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: EmptyView(message: 'No $status payments', icon: Icons.payments_outlined),
            )
          else
            ...list.map((t) => _paymentCard(t, status)),
        ],
      ),
    );
  }

  Widget _paymentCard(dynamic t, String status) {
    final (badgeColor, badgeLabel) = _statusBadge(status);
    final cashfreeOrderId = t['cashfreeOrderId'];
    // Cashfree transactions show their Order ID; any older transaction
    // from before the Cashfree migration falls back to its UTR number.
    final referenceLabel = (cashfreeOrderId != null && cashfreeOrderId.toString().isNotEmpty)
        ? 'Order ${cashfreeOrderId}'
        : 'UTR ${t['utrNumber'] ?? '-'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaces.card2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.purple.withOpacity(0.15),
                      child: Text(
                        (t['userDisplayId'] ?? '?').toString().substring(0, 1),
                        style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['userDisplayId'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                          Text(t['user']?['email'] ?? '', style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${t['amountINR']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${t['diamondPackage']}', style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
                      const SizedBox(width: 2),
                      const Text('💎', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 13, color: context.surfaces.textDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(referenceLabel, style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.schedule, size: 13, color: context.surfaces.textDim),
                const SizedBox(width: 4),
                Text(formatDateTime(t['createdAt']), style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
              ],
            ),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.diamond.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.diamond),
                    ),
                    const SizedBox(width: 6),
                    Text('auto-checking', style: TextStyle(color: AppColors.diamond, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status == 'approved' ? Icons.check_circle : Icons.cancel, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (users.isEmpty && !usersLoading && _searchCtrl.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUsers());
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.surfaces.card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.surfaces.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by username, email, or user ID',
                hintStyle: TextStyle(fontSize: 13, color: context.surfaces.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: context.surfaces.textDim),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _loadUsers(); })
                    : null,
              ),
              onSubmitted: (v) => _loadUsers(search: v.trim()),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: usersLoading
                ? const LoadingView()
                : users.isEmpty
                    ? const EmptyView(message: 'No users found', icon: Icons.people_outline)
                    : RefreshIndicator(
                        color: AppColors.purple,
                        onRefresh: () => _loadUsers(search: _searchCtrl.text.trim()),
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            final isActive = u['isActive'] ?? true;
                            final displayName = (u['username'] ?? u['email'] ?? 'U').toString();
                            final deleteLabel = (u['username'] ?? u['email'] ?? 'User').toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surfaces.card2,
                                border: Border.all(color: context.surfaces.border),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: (isActive ? AppColors.green : AppColors.red).withOpacity(0.15),
                                              child: Text(
                                                displayName.substring(0, 1).toUpperCase(),
                                                style: TextStyle(color: isActive ? AppColors.green : AppColors.red, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('@${u['username'] ?? u['userId'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 2),
                                                  Text(u['email'] ?? '-', style: TextStyle(color: context.surfaces.textDim, fontSize: 12), overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text('${u['userId'] ?? ''}', style: TextStyle(color: context.surfaces.textDim, fontSize: 11)),
                                                      const SizedBox(width: 6),
                                                      Text('💎 ${u['diamondBalance'] ?? 0}', style: const TextStyle(color: AppColors.diamond, fontSize: 11, fontWeight: FontWeight.w700)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isActive ? AppColors.green : AppColors.red).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isActive ? 'Active' : 'Suspended',
                                          style: TextStyle(color: isActive ? AppColors.green : AppColors.red, fontSize: 10.5, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _forceLogout(u['_id'], u['username'] ?? u['email'] ?? 'User'),
                                        icon: const Icon(Icons.logout, size: 14),
                                        label: const Text('Force Logout', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _toggleActive(u['_id'], u['username'] ?? u['email'] ?? 'User'),
                                        icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 14),
                                        label: Text(isActive ? 'Suspend' : 'Reactivate', style: const TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isActive ? AppColors.red : AppColors.green,
                                          side: BorderSide(color: isActive ? AppColors.red : AppColors.green),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _deleteAccount(u['_id'], deleteLabel),
                                      icon: const Icon(Icons.delete_forever, size: 14),
                                      label: const Text('Delete Account', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.red,
                                        side: const BorderSide(color: AppColors.red),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ---------------- Gift Codes tab UI ----------------
  Widget _buildGiftCodesTab() {
    if (giftCodes.isEmpty && !giftCodesLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGiftCodes());
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- Generate Gift Code ----------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaces.card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Generate Gift Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 10),
                TextField(
                  controller: _giftCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Custom code (optional — leave blank to auto-generate)'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Diamond value:', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('2 💎'),
                    selected: _newGiftCodeValue == 2,
                    onSelected: (_) => setState(() => _newGiftCodeValue = 2),
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _newGiftCodeValue == 2 ? Colors.white : null, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('3 💎'),
                    selected: _newGiftCodeValue == 3,
                    onSelected: (_) => setState(() => _newGiftCodeValue = 3),
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _newGiftCodeValue == 3 ? Colors.white : null, fontWeight: FontWeight.w700),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: creatingGiftCode ? null : _createGiftCode,
                    icon: creatingGiftCode
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Code'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('All Gift Codes', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: giftCodesLoading
                ? const LoadingView()
                : giftCodes.isEmpty
                    ? const EmptyView(message: 'No gift codes yet', icon: Icons.card_giftcard_outlined)
                    : RefreshIndicator(
                        color: AppColors.purple,
                        onRefresh: _loadGiftCodes,
                        child: ListView.builder(
                          itemCount: giftCodes.length,
                          itemBuilder: (_, i) {
                            final g = giftCodes[i];
                            final active = g['active'] == true;
                            final redemptions = (g['redeemedBy'] as List?)?.length ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surfaces.card2,
                                border: Border.all(color: context.surfaces.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(g['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                                          const SizedBox(width: 8),
                                          AppBadge(label: '${g['diamondValue']} 💎', color: AppColors.diamond),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text('$redemptions redemption${redemptions == 1 ? '' : 's'}', style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: active,
                                    activeTrackColor: AppColors.purple,
                                    onChanged: (_) => _toggleGiftCodeActive(g['_id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}