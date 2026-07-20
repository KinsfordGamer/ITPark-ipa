import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../main.dart';

class StudentsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const StudentsScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _students = [];
  List<dynamic> _groups = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<int, int> _studentStars = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadCacheAndFetch().then((_) => _loadStars());
  }

  Future<void> _loadStars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final s in _students) {
        final int? sid = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '');
        if (sid != null) {
          _studentStars[sid] = prefs.getInt('student_stars_$sid') ?? 0;
        }
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _saveStars(int studentId, int stars) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('student_stars_$studentId', stars);
      setState(() {
        _studentStars[studentId] = stars;
      });
    } catch (_) {}
  }

  Future<void> _loadCacheAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedS = prefs.getString('cached_students');
      final cachedG = prefs.getString('cached_groups');
      if (cachedS != null && cachedG != null) {
        final sData = jsonDecode(cachedS);
        final gData = jsonDecode(cachedG);
        _parseAndFilter(sData, gData);
        setState(() => _isLoading = false);
      }
    } catch (_) {}
    _fetchAll();
  }

  void _parseAndFilter(dynamic sData, dynamic gData) {
    List<dynamic> allStudents = [];
    if (sData is List) {
      allStudents = sData;
    } else if (sData is Map) {
      allStudents = sData['data'] ?? sData['results'] ?? [];
    }

    List<dynamic> allGroups = [];
    if (gData is List) {
      allGroups = gData;
    } else if (gData is Map) {
      allGroups = gData['data'] ?? gData['results'] ?? [];
    }

    // If teacher, filter groups and students
    if (widget.user['role'] == 'teacher') {
      final String teacherIdStr = widget.user['id']?.toString() ?? '';
      allGroups = allGroups.where((g) => g['teacher']?.toString() == teacherIdStr).toList();
      
      final teacherGroupIds = allGroups.map((g) => g['id']?.toString()).whereType<String>().toList();
      
      allStudents = allStudents.where((s) {
        final sGroupIds = s['groupIds'] ?? s['groupId'];
        if (sGroupIds is List) {
          return sGroupIds.any((id) => teacherGroupIds.contains(id?.toString()));
        } else if (sGroupIds != null) {
          return teacherGroupIds.contains(sGroupIds.toString());
        }
        return false;
      }).toList();
    }

    _students = allStudents;
    _groups = allGroups;
    _filtered = List.from(_students);
  }

  Future<void> _fetchAll() async {
    if (_students.isEmpty) setState(() => _isLoading = true);
    try {
      final sRes = await ApiService.getStudents(widget.token);
      final gRes = await ApiService.getGroups(widget.token);
      if (sRes.statusCode == 200 && gRes.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_students', sRes.body);
        await prefs.setString('cached_groups', gRes.body);

        final sData = jsonDecode(sRes.body);
        final gData = jsonDecode(gRes.body);
        
        setState(() {
          _parseAndFilter(sData, gData);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        final name = '${s['first_name'] ?? s['firstName'] ?? ''} ${s['last_name'] ?? s['lastName'] ?? ''}'.toLowerCase();
        final phone = (s['phone'] ?? '').toLowerCase();
        final sid = (s['student_id'] ?? s['studentId'] ?? '').toString().toLowerCase();
        
        // Remove test students from teacher view
        final isTest = name.contains('test');
        if (widget.user['role'] == 'teacher' && isTest) return false;

        return q.isEmpty || name.contains(q) || phone.contains(q) || sid.contains(q);
      }).toList();
    });
  }

  String _getGroupName(dynamic groupIds) {
    if (groupIds == null || (groupIds is List && groupIds.isEmpty)) return '—';
    final id = groupIds is List ? groupIds.first : groupIds;
    final g = _groups.firstWhere((g) => g['id'] == id, orElse: () => null);
    return g?['name'] ?? '—';
  }

  void _showPaymentDialog(Map<String, dynamic> student) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          final studentId = student['id'];
          final studentName = '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}';
          final groupIds = student['groupIds'] ?? student['groupId'];
          final amountCtrl = TextEditingController();
          final noteCtrl = TextEditingController();
          int? selectedGroupId;
          String selectedMethod = 'cash';

          if (groupIds is List && groupIds.isNotEmpty) {
            selectedGroupId = groupIds.first;
          } else if (groupIds is int) {
            selectedGroupId = groupIds;
          }

          final now = DateTime.now();
          final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

          return Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 96,
                      ),
                      child: Hero(
                        tag: 'pay_btn_${student['id']}',
                        child: Material(
                          color: const Color(0xFF131C2E),
                          borderRadius: BorderRadius.circular(24),
                          elevation: 16,
                          child: StatefulBuilder(
                            builder: (ctx, setModalState) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFF00B050).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                        child: const Icon(Icons.payments_rounded, color: Color(0xFF00B050)),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('To\'lov qabul qilish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                          Text(studentName, style: const TextStyle(color: Color(0xFF00B050), fontSize: 13, fontWeight: FontWeight.normal)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Amount
                                  TextField(
                                    controller: amountCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Summa (so\'m)',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF00B050)),
                                      filled: true,
                                      fillColor: const Color(0xFF0C101B),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF00B050), width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Method selector
                                  Row(
                                    children: [
                                      for (final m in [
                                        {'val': 'cash', 'label': 'Naqd', 'icon': Icons.money},
                                        {'val': 'card', 'label': 'Karta', 'icon': Icons.credit_card},
                                        {'val': 'transfer', 'label': 'O\'tkazma', 'icon': Icons.send},
                                      ])
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setModalState(() => selectedMethod = m['val'] as String),
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: selectedMethod == m['val']
                                                    ? const Color(0xFF00B050)
                                                    : const Color(0xFF0C101B),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: selectedMethod == m['val']
                                                      ? const Color(0xFF00B050)
                                                      : Colors.white12,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(m['icon'] as IconData,
                                                      color: selectedMethod == m['val'] ? Colors.white : Colors.white38,
                                                      size: 20),
                                                  const SizedBox(height: 2),
                                                  Text(m['label'] as String,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: selectedMethod == m['val'] ? Colors.white : Colors.white38,
                                                          fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Note
                                  TextField(
                                    controller: noteCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Izoh (ixtiyoriy)',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.white38),
                                      filled: true,
                                      fillColor: const Color(0xFF0C101B),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00B050),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: () async {
                                        final amount = double.tryParse(amountCtrl.text.trim());
                                        if (amount == null || selectedGroupId == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Summa va guruhni tekshiring')),
                                          );
                                          return;
                                        }
                                        try {
                                          final res = await ApiService.createPayment(widget.token, {
                                            'student': studentId,
                                            'group': selectedGroupId,
                                            'amount': amount,
                                            'discount': 0,
                                            'discount_months': 1,
                                            'month': currentMonth,
                                            'method': selectedMethod,
                                          });
                                          if (res.statusCode == 201 || res.statusCode == 200) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('✅ To\'lov muvaffaqiyatli saqlandi'),
                                                backgroundColor: Color(0xFF00B050),
                                              ),
                                            );
                                            _fetchAll();
                                          } else {
                                            if (!ApiService.handleAuthError(context, res)) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Xato: ${res.body}')),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Xatolik: $e')),
                                          );
                                        }
                                      },
                                      child: const Text('Tasdiqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    final rawName = '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    final cleanName = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
    final studentId = student['student_id'] ?? student['studentId'] ?? 'Noma\'lum';
    final phone = student['phone'] ?? 'Noma\'lum';
    final phoneExtra = student['phone_extra'] ?? 'Kiritilmagan';
    final createdAt = (student['created_at'] ?? student['createdAt'] ?? '').toString().split('T')[0];
    final isFrozen = student['is_frozen'] ?? student['isFrozen'] ?? false;
    final groupName = _getGroupName(student['groupIds']);
    final debt = (student['debtThisMonth'] ?? 0.0);
    final paid = (student['paidThisMonth'] ?? 0.0);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF00B050).withOpacity(0.2),
                  child: Text(
                    cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00B050)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cleanName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Student ID: $studentId', style: const TextStyle(color: Color(0xFF00B050), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildDetailRow(Icons.calendar_today_rounded, 'Kelishni boshlagan vaqti', createdAt),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.phone_rounded, 'Telefon raqami', phone),
            if (phoneExtra.isNotEmpty && phoneExtra != 'Kiritilmagan') ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone_iphone_rounded, 'Qo\'shimcha telefon', phoneExtra),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(Icons.class_rounded, 'Guruh', groupName),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.info_outline_rounded,
              'Holati',
              isFrozen ? 'Muzlatilgan' : 'Faol',
              textColor: isFrozen ? Colors.redAccent : const Color(0xFF00B050),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.account_balance_wallet_rounded,
              'Moliyaviy holat',
              debt > 0 ? 'Qarzdorlik: ${debt.toInt()} so\'m' : 'To\'langan: ${paid.toInt()} so\'m',
              textColor: debt > 0 ? Colors.redAccent : const Color(0xFF00B050),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.star_rounded,
              'Yulduzchalari',
              '${student['stars'] ?? 0} ta',
              textColor: Colors.amber,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? textColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00B050), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: textColor ?? Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  void _showSendMessageDialog(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StudentDirectChatWidget(
        token: widget.token,
        user: widget.user,
        student: student,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))));

    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(context);
    final border = AppTheme.border(context);

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Ism, telefon yoki ID bo\'yicha qidirish...',
              hintStyle: TextStyle(color: textSecColor.withOpacity(0.6), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: textSecColor),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: textSecColor),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text('${_filtered.length} ta o\'quvchi', style: TextStyle(color: textSecColor, fontSize: 13)),
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAll,
            color: const Color(0xFF00B050),
            child: _filtered.isEmpty
                ? Center(child: Text('O\'quvchi topilmadi', style: TextStyle(color: textSecColor)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 125),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}';
                      final phone = s['phone'] ?? '';
                      final debt = (s['debtThisMonth'] ?? 0.0);
                      final paid = (s['paidThisMonth'] ?? 0.0);
                      final groupName = _getGroupName(s['groupIds']);
                      final hasDebt = (debt is num) && debt > 0;
                      final bool isGuruhsiz = s['groupIds'] == null || (s['groupIds'] is List && (s['groupIds'] as List).isEmpty);
                      bool isCompletedGroup = false;
                      if (!isGuruhsiz) {
                        final id = s['groupIds'] is List ? (s['groupIds'] as List).first : s['groupIds'];
                        final g = _groups.firstWhere((g) => g['id'] == id, orElse: () => null);
                        if (g != null) {
                          final gStatus = (g['status'] ?? '').toString().toLowerCase();
                          final gStage = (g['stage'] ?? '').toString().toLowerCase();
                          final gName = (g['name'] ?? '').toString().toLowerCase();
                          if (gStatus == 'completed' || gStatus == 'finished' || gStatus == 'archive' || gStatus == 'tugagan' ||
                              gStage == 'completed' || gStage == 'finished' || gStage == 'archive' || gStage == 'tugagan' ||
                              gName.contains('tugagan') || gName.contains('finished') || gName.contains('completed')) {
                            isCompletedGroup = true;
                          }
                        }
                      }

                      return PremiumFadeIn(
                        duration: Duration(milliseconds: 300 + (index * 40)),
                        child: ThreeDContainer(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.zero,
                          border: Border.all(
                            color: hasDebt ? Colors.redAccent.withOpacity(0.3) : border,
                            width: 1,
                          ),
                          child: ListTile(
                            onTap: () => _showStudentDetails(s),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: hasDebt
                                  ? Colors.redAccent.withOpacity(0.2)
                                  : const Color(0xFF00B050).withOpacity(0.2),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: hasDebt ? Colors.redAccent : const Color(0xFF00B050)),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. $name',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${s['stars'] ?? 0}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.groups_rounded, size: 12, color: textSecColor),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        groupName,
                                        style: TextStyle(color: textSecColor, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.phone, size: 12, color: textSecColor),
                                    const SizedBox(width: 4),
                                    Text(phone, style: TextStyle(color: textSecColor, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (isGuruhsiz)
                                  const Text('Guruhsiz', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))
                                else if (isCompletedGroup)
                                  const Text('Tugatgan', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold))
                                else if (hasDebt)
                                  Text('Qarzdor: ${_fmt(debt)} so\'m',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
                                else
                                  Text('To\'langan: ${_fmt(paid)} so\'m',
                                      style: const TextStyle(color: Color(0xFF00B050), fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(3, (starIdx) {
                                    final int? sid = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '');
                                    if (sid == null) return const SizedBox();
                                    final stars = _studentStars[sid] ?? 0;
                                    final isFilled = starIdx < stars;
                                    return GestureDetector(
                                      onTap: () {
                                        if (stars == starIdx + 1) {
                                          _saveStars(sid, 0);
                                        } else {
                                          _saveStars(sid, starIdx + 1);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                                  onPressed: () => _showSendMessageDialog(s),
                                ),
                                if (widget.user['role'] == 'admin' || widget.user['role'] == 'superadmin')
                                  Hero(
                                    tag: 'pay_btn_${s['id']}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: IconButton(
                                        icon: const Icon(Icons.payments_rounded, color: Color(0xFF00B050)),
                                        onPressed: () => _showPaymentDialog(s),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _fmt(dynamic amount) {
    final val = (amount is num) ? amount.toInt() : int.tryParse(amount.toString()) ?? 0;
    final str = val.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return val < 0 ? '-${buffer.toString()}' : buffer.toString();
  }
}

class StudentDirectChatWidget extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic> student;

  const StudentDirectChatWidget({
    Key? key,
    required this.token,
    required this.user,
    required this.student,
  }) : super(key: key);

  @override
  _StudentDirectChatWidgetState createState() => _StudentDirectChatWidgetState();
}

class _StudentDirectChatWidgetState extends State<StudentDirectChatWidget> {
  final List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollingTimer;
  int? _lastScrollMessageCount;

  @override
  void initState() {
    super.initState();
    _loadMessages(isInitial: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool isInitial = false}) async {
    try {
      final res = await ApiService.getMessages(widget.token);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> rawMessages = [];
        if (decoded is List) {
          rawMessages = decoded;
        } else if (decoded is Map) {
          rawMessages = decoded['results'] ?? decoded['data'] ?? [];
        }

        final prefix = '[student_id:${widget.student['id']}]';
        final filtered = rawMessages.where((m) {
          final text = m['text']?.toString() ?? '';
          return text.startsWith(prefix);
        }).toList();

        filtered.sort((a, b) {
          final idA = a['id'] ?? 0;
          final idB = b['id'] ?? 0;
          return idA.compareTo(idB);
        });

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(filtered);
            _isLoading = false;
          });

          if (isInitial || _lastScrollMessageCount == null || _messages.length > _lastScrollMessageCount!) {
            _scrollToBottom();
            _lastScrollMessageCount = _messages.length;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching student direct messages: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    try {
      final formattedText = '[student_id:${widget.student['id']}] $text';
      final res = await ApiService.sendMessage(widget.token, formattedText);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _loadMessages();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending student direct message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawName = '${widget.student['first_name'] ?? ''} ${widget.student['last_name'] ?? ''}'.trim();
    final studentName = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
    final prefix = '[student_id:${widget.student['id']}]';
    final primaryColor = const Color(0xFF00B050);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      const Text('Shaxsiy xabarlar', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B050)))
                : _messages.isEmpty
                    ? const Center(child: Text('Hozircha xabarlar yo\'q', style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final m = _messages[idx];
                          final rawText = m['text']?.toString() ?? '';
                          if (!rawText.startsWith(prefix)) return const SizedBox();

                          final bodyText = rawText.substring(prefix.length).trim();
                          final isFromStudent = bodyText.startsWith('[from_student]');
                          final text = isFromStudent ? bodyText.substring('[from_student]'.length).trim() : bodyText;
                          final time = _formatTime(m['created_at'] ?? m['createdAt']);

                          return Align(
                            alignment: isFromStudent ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isFromStudent ? const Color(0xFF161F30) : primaryColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isFromStudent ? 2 : 12),
                                  bottomRight: Radius.circular(isFromStudent ? 12 : 2),
                                ),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                                  const SizedBox(height: 4),
                                  Text(time, style: const TextStyle(color: Colors.white60, fontSize: 9)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0C101B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Xabar yozing...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                  ),
                ),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00B050), strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF00B050)),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
