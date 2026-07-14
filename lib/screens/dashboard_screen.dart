import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const DashboardScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCacheAndFetch();
  }

  Future<void> _loadCacheAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_dashboard_stats');
      if (cached != null) {
        setState(() {
          _stats = jsonDecode(cached);
          _isLoading = false;
        });
      }
    } catch (_) {}
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (_stats == null) setState(() => _isLoading = true);
    try {
      final res = await ApiService.getDashboardStats(widget.token);
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_dashboard_stats', res.body);
        setState(() {
          _stats = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))));
    }

    final stats = _stats ?? {};
    final totalStudents = stats['totalStudents'] ?? 0;
    final totalGroups = stats['activeGroups'] ?? 0;
    final monthlyRevenue = stats['monthlyIncome'] ?? 0;
    final todayRevenue = stats['todayIncome'] ?? 0;
    final debtors = stats['debtCount'] ?? 0;

    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);

    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: const Color(0xFF00B050),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 125),
        children: [
          // Header
          PremiumFadeIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B050), Color(0xFF00873C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B050).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _getGreeting(),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.user['firstName'] ?? ''} ${widget.user['lastName'] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _headerStat('Bugun', _formatMoney(todayRevenue), Icons.today_rounded),
                      const SizedBox(width: 20),
                      _headerStat('Bu oy', _formatMoney(monthlyRevenue), Icons.calendar_month_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Umumiy ko\'rsatkichlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),

          PremiumFadeIn(
            duration: const Duration(milliseconds: 400),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _statCard('O\'quvchilar', '$totalStudents ta', Icons.people_rounded, const Color(0xFF3B82F6)),
                _statCard('Guruhlar', '$totalGroups ta', Icons.groups_rounded, const Color(0xFF8B5CF6)),
                _statCard('Qarzdorlar', '$debtors ta', Icons.warning_rounded, Colors.orangeAccent),
                _statCard('Bu oy tushum', _formatMoney(monthlyRevenue), Icons.account_balance_rounded, const Color(0xFF00B050)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    final textSecColor = AppTheme.textSecondary(context);
    return ThreeDContainer(
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      depth: 2.0,
      shadowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(color: textSecColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ThreeDContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      margin: EdgeInsets.zero,
      onTap: onTap,
      gradientColors: [
        color.withOpacity(isDark ? 0.08 : 0.05),
        color.withOpacity(isDark ? 0.12 : 0.08)
      ],
      border: Border.all(color: color.withOpacity(0.25), width: 1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Xayrli tong!';
    if (hour < 17) return 'Xayrli kun!';
    return 'Xayrli kech!';
  }

  String _formatMoney(dynamic amount) {
    final val = (amount is num) ? amount.toInt() : int.tryParse(amount.toString()) ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)} mln';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)} ming';
    return '$val';
  }
}
