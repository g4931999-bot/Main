import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/language_provider.dart';
import '../widgets/common.dart';
import '../widgets/brand_icons.dart';
import 'upload_screen.dart';
import 'upcoming_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'diamond_store_screen.dart';
import 'wallet_screen.dart';
import 'notifications_screen.dart';
import 'preview_screen.dart';
import 'rate_us_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _DashboardHome(),
      const UploadScreen(embedded: true),
      const UpcomingScreen(embedded: true),
      const AnalyticsScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: AppBottomNav(currentIndex: _tabIndex, onTap: (i) => setState(() => _tabIndex = i)),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();
  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  Map<String, dynamic>? data;
  List<dynamic> notifications = [];
  int unreadCount = 0;

  Map<String, dynamic>? youtubeChannel;
  Map<String, dynamic>? facebookStatus;

  List<Map<String, dynamic>> upcomingEvents = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted) maybeShowRateUsPopup(context);
    });
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) setState(() => loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.dashboard(),
        ApiService.instance.getNotifications(),
        ApiService.instance.getYoutubeChannel().catchError((_) => <String, dynamic>{}),
        ApiService.instance.getMetaStatus().catchError((_) => <String, dynamic>{}),
        ApiService.instance.listVideos(status: 'queued').catchError((_) => <String, dynamic>{}),
      ]);

      final dash = results[0]['data'];
      final notifRes = results[1];
      final ytRes = results[2];
      final metaRes = results[3];
      final videosRes = results[4];

      final events = <Map<String, dynamic>>[];
      final videos = (videosRes['videos'] as List?) ?? [];
      for (final v in videos) {
        final platforms = (v['platforms'] as List?) ?? [];
        for (final p in platforms) {
          if (p['status'] != 'pending' && p['status'] != 'queued') continue;
          events.add({
            'videoId': v['_id'],
            'platform': p['platform'],
            'title': p['platform'] == 'youtube'
                ? (p['title'] ?? 'Untitled')
                : ((p['caption'] ?? '').toString().isNotEmpty ? p['caption'] : 'Untitled'),
            'scheduledAt': p['scheduledAt'],
            'thumbnailUrl': p['thumbnailUrl'] ?? '',
            'status': p['status'],
          });
        }
      }
      events.sort((a, b) {
        final aTime = a['scheduledAt'] as String?;
        final bTime = b['scheduledAt'] as String?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return aTime.compareTo(bTime);
      });

      setState(() {
        data = dash;
        notifications = (notifRes['notifications'] as List?) ?? [];
        unreadCount = notifRes['unreadCount'] ?? 0;
        youtubeChannel = ytRes['success'] == true ? ytRes['channel'] : null;
        facebookStatus = metaRes['facebook'];
        upcomingEvents = events.take(5).toList();
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (showLoader && mounted) setState(() => loading = false);
    }
  }

  void _goToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _load(showLoader: false));
  }

  void _openPreview(Map<String, dynamic> event) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpcomingScreen())).then((_) => _load(showLoader: false));
  }

  String? get _userEmail {
    final email = data?['email'] ?? data?['user']?['email'] ?? data?['account']?['email'];
    return (email is String && email.isNotEmpty) ? email : null;
  }

  String get _userInitial {
    final email = _userEmail;
    return (email != null) ? email.trim()[0].toUpperCase() : '?';
  }

  int get _diamondCostPerUpload {
    final cost = data?['diamondCostPerUpload'] ?? data?['uploadCostDiamonds'];
    if (cost is num && cost > 0) return cost.toInt();
    return 10;
  }

  // Mirrors getUserDailyPostLimit() in routes/video.js: an active,
  // non-expired subscription unlocks Premium's 2-posts/day cap; everyone
  // else is on Free's 1-post/day cap.
  bool get _isPremiumActive {
    final sub = data?['subscriptionStatus'];
    if (sub is! Map) return false;
    final isActive = sub['isActive'] == true;
    final expiresAtRaw = sub['expiresAt'];
    if (!isActive) return false;
    if (expiresAtRaw == null) return true;
    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    return expiresAt == null || expiresAt.isAfter(DateTime.now());
  }

  int get _dailyPostLimit => _isPremiumActive ? 2 : 1;

  Widget _planLimitBanner(BuildContext context) {
    final premium = _isPremiumActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: (premium ? AppColors.green : AppColors.purple).withOpacity(0.10),
        border: Border.all(color: (premium ? AppColors.green : AppColors.purple).withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(premium ? Icons.workspace_premium_rounded : Icons.info_outline_rounded,
              color: premium ? AppColors.green : AppColors.purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              premium
                  ? 'Daily Limit: $_dailyPostLimit Posts / Day (Premium Active)'
                  : 'Daily Limit: $_dailyPostLimit Post / Day (Free Plan)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          if (!premium)
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiamondStoreScreen())).then((_) => _load(showLoader: false)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  ({String label, Color color}) _platformMeta(BuildContext context, String? platform) {
    switch (platform) {
      case 'youtube':
        return (label: context.tr('platform_youtube_label'), color: AppColors.red);
      case 'facebook':
        return (label: context.tr('platform_facebook_label'), color: AppColors.diamond);
      default:
        return (label: platform ?? '', color: AppColors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diamondBalance = (data?['diamondBalance'] ?? 0) as num;
    final worthUploads = diamondBalance ~/ _diamondCostPerUpload;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_title')),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _load(showLoader: false)),
              ),
              if (unreadCount > 0)
                Positioned(right: 10, top: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 2),
            child: Tooltip(
              message: context.tr('profile_tooltip'),
              child: GestureDetector(
                onTap: _goToProfile,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                  ),
                  // ⚠️ FIX: previously always showed the account's initial
                  // letter here. Now shows the REAL connected YouTube
                  // channel's logo when one is connected — falls back to
                  // the initial letter only if no channel is connected yet
                  // (or its thumbnail fails to load).
                  child: (youtubeChannel != null && (youtubeChannel!['thumbnail'] ?? '').toString().isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            youtubeChannel!['thumbnail'],
                            width: 34, height: 34, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              _userInitial,
                              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        )
                      : Text(
                          _userInitial,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: () => _load(showLoader: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  // ---------------- Diamond Balance card ----------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: AppColors.purple.withOpacity(0.30), blurRadius: 22, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
                              ),
                              child: const Text('💎', style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('diamond_balance_home'), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$diamondBalance',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.05),
                                  ),
                                  if (worthUploads > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmt(context.tr('diamonds_worth_uploads'), worthUploads),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())).then((_) => _load(showLoader: false)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: Text(context.tr('top_up'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiamondStoreScreen())).then((_) => _load(showLoader: false)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.purple,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: Text(context.tr('buy_more'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ---------------- Quick Upload ----------------
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen())).then((_) => _load(showLoader: false)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.55), width: 1.3),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                                  child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 14),
                                ),
                                const SizedBox(width: 10),
                                Text(context.tr('quick_upload'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _planLimitBanner(context),

                  // ---------------- Connected Accounts row ----------------
                  // ⚠️ Google Drive card removed — Drive auto-upload is no
                  // longer part of the app. Only YouTube + Facebook now.
                  Text(context.tr('connected_accounts_home'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _accountCard(
                          icon: const YoutubeIcon(size: 20),
                          label: youtubeChannel != null ? (youtubeChannel!['channelTitle'] ?? context.tr('platform_youtube_label')) : context.tr('platform_youtube_label'),
                          connected: youtubeChannel != null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _accountCard(
                          icon: const FacebookIcon(size: 20),
                          label: facebookStatus != null ? (facebookStatus!['pageName'] ?? context.tr('platform_facebook_label')) : context.tr('platform_facebook_label'),
                          connected: facebookStatus != null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------------- Stats grid ----------------
                  Text(context.tr('overview'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      StatCard(label: context.tr('stat_free_uploads_left'), value: '${data?['remainingFreeUploads'] ?? 0}'),
                      StatCard(label: context.tr('stat_diamond_balance'), value: '$diamondBalance'),
                      StatCard(label: context.tr('stat_videos_published'), value: '${data?['totalUploadedVideos'] ?? 0}'),
                      StatCard(label: context.tr('stat_scheduled'), value: '${upcomingEvents.length}'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------------- Upcoming Schedule timeline ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('upcoming_schedule'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpcomingScreen())),
                        child: Text(context.tr('see_all'), style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTimeline(),
                  const SizedBox(height: 24),

                  // ---------------- Recent Activity ----------------
                  Text(context.tr('recent_activity_home'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _buildRecentActivity(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _fmt(String template, Object value) => template.replaceFirst('%d', '$value').replaceFirst('%s', '$value');

  Widget _accountCard({required Widget icon, required String label, required bool connected}) {
    return GestureDetector(
      onTap: _goToProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaces.card2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (connected ? AppColors.green : context.surfaces.textDim).withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: connected ? AppColors.green : context.surfaces.textDim, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(connected ? context.tr('connected_status') : context.tr('connect_status'), style: TextStyle(color: context.surfaces.textDim, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    if (upcomingEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
        child: Text(context.tr('no_upcoming_publishes'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
      );
    }

    return Column(
      children: List.generate(upcomingEvents.length, (i) {
        final event = upcomingEvents[i];
        final meta = _platformMeta(context, event['platform']);
        final isLast = i == upcomingEvents.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2)),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: context.surfaces.border)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openPreview(event),
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        _platformBadgeIcon(event['platform']),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta.label, style: TextStyle(color: context.surfaces.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(event['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              const SizedBox(height: 4),
                              Text(
                                event['scheduledAt'] != null ? formatDateTime(event['scheduledAt']) : context.tr('publishing_now'),
                                style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        AppBadge(label: event['status'] == 'pending' ? context.tr('status_scheduled') : context.tr('status_queued'), color: meta.color),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _platformBadgeIcon(String? platform) {
    switch (platform) {
      case 'youtube':
        return const YoutubeIcon(size: 16);
      case 'facebook':
        return const FacebookIcon(size: 16);
      default:
        return const Icon(Icons.movie_outlined, size: 16);
    }
  }

  Widget _buildRecentActivity() {
    final recent = notifications.take(4).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
        child: Text(context.tr('no_recent_activity'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: List.generate(recent.length, (i) {
          final n = recent[i];
          final isRead = n['isRead'] == true;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: (isRead ? context.surfaces.textDim : AppColors.purple).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    n['type']?.toString().contains('failed') == true ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isRead ? context.surfaces.textDim : AppColors.purple,
                    size: 17,
                  ),
                ),
                title: Text(n['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(n['message'] ?? '', style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                dense: true,
              ),
              if (i != recent.length - 1) Divider(height: 1, color: context.surfaces.border),
            ],
          );
        }),
      ),
    );
  }
}