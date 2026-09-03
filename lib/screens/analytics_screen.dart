import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../providers/language_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool embedded;
  const AnalyticsScreen({super.key, this.embedded = false});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? analytics;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) setState(() => loading = true);
    try {
      final res = await ApiService.instance.getAnalytics();
      setState(() => analytics = res['analytics']);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (showLoader && mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trend = (analytics?['uploadTrend'] as List?) ?? [];
    final activity = (analytics?['recentActivity'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('analytics_title'))),
      body: loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: () => _load(showLoader: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard(context, Icons.cloud_done_rounded, context.tr('total_uploaded'), '${analytics?['uploadCount'] ?? 0}'),
                      _statCard(context, Icons.card_giftcard_rounded, context.tr('free_uploads_left'), '${analytics?['freeUploadsLeft'] ?? 0}'),
                      _statCard(context, Icons.diamond_rounded, context.tr('diamond_balance'), '${analytics?['remainingUploadCredits'] ?? 0}'),
                      _statCard(context, Icons.schedule_rounded, context.tr('scheduled_queue'), '${analytics?['scheduledQueue'] ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---------------- 14-day upload trend chart ----------------
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('uploads_last_14_days'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(context.tr('uploads_consistency_subtitle'), style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: trend.isEmpty ? _emptyChartPlaceholder(context) : _buildTrendChart(context, trend),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(context.tr('failed_uploads'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          AppBadge(label: '${analytics?['failedUploads'] ?? 0}', color: AppColors.red),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('analytics_placeholder_note'),
                          style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---------------- Recent activity / usage record ----------------
                  Text(context.tr('recent_activity'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (activity.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
                      child: Text(context.tr('no_activity_yet'), style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
                    )
                  else
                    ...activity.map((a) => _activityRow(context, a as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.card2,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.purple.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.purple, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChartPlaceholder(BuildContext context) {
    return Center(
      child: Text(context.tr('no_uploads_14_days'), style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5)),
    );
  }

  Widget _buildTrendChart(BuildContext context, List trend) {
    final counts = trend.map((t) => (t['count'] as num?)?.toDouble() ?? 0).toList();
    final maxY = (counts.isEmpty ? 1.0 : counts.reduce((a, b) => a > b ? a : b));
    final barMaxY = maxY < 4 ? 4.0 : maxY + 1;

    return BarChart(
      BarChartData(
        maxY: barMaxY,
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                // Only label every other day to avoid crowding
                if (i % 2 != 0) return const SizedBox.shrink();
                final dateStr = trend[i]['date'] as String;
                final d = DateTime.tryParse(dateStr);
                final label = d == null ? '' : '${d.day}/${d.month}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: TextStyle(color: context.surfaces.textDim, fontSize: 9.5)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(trend.length, (i) {
          final count = counts[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count,
                width: 10,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: count > 0 ? [AppColors.purpleLight, AppColors.purple] : [context.surfaces.border, context.surfaces.border],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _activityRow(BuildContext context, Map<String, dynamic> a) {
    final usedFreeUpload = a['usedFreeUpload'] == true;
    final diamondsCharged = a['diamondsCharged'] ?? 0;
    final status = a['status'] ?? '';
    final title = a['title'] ?? '';
    final date = a['createdAt'] as String?;

    final statusColor = status == 'uploaded'
        ? AppColors.green
        : status == 'failed'
            ? AppColors.red
            : AppColors.diamond;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(
              usedFreeUpload ? Icons.card_giftcard_rounded : Icons.diamond_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  usedFreeUpload
                      ? context.tr('used_free_upload')
                      : (diamondsCharged > 0 ? context.tr('spent_diamonds').replaceAll('%d', '$diamondsCharged') : context.tr('no_charge')),
                  style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppBadge(label: status, color: statusColor),
              const SizedBox(height: 4),
              Text(formatDate(date), style: TextStyle(color: context.surfaces.textDim, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}