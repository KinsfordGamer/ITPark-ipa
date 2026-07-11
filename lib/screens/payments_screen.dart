import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../main.dart';

class PaymentsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const PaymentsScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _payments = [];
  List<dynamic> _students = [];
  List<dynamic> _groups = [];
  bool _isLoading = true;

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
      final cachedP = prefs.getString('cached_payments');
      final cachedG = prefs.getString('cached_groups');
      final cachedS = prefs.getString('cached_students');
      if (cachedP != null && cachedG != null && cachedS != null) {
        final pData = jsonDecode(cachedP);
        final gData = jsonDecode(cachedG);
        final sData = jsonDecode(cachedS);
        _parseAndFilter(gData, sData, pData);
        setState(() => _isLoading = false);
      }
    } catch (_) {}
    _fetchAll();
  }

  void _parseAndFilter(dynamic gData, dynamic sData, dynamic pData) {
    List<dynamic> allGroups = [];
    if (gData is List) {
      allGroups = gData;
    } else if (gData is Map) {
      allGroups = gData['data'] ?? gData['results'] ?? [];
    }
    // Remove test groups
    allGroups = allGroups.where((g) => !(g['name'] ?? '').toString().toLowerCase().contains('test')).toList();
    
    if (widget.user['role'] == 'teacher') {
      final String teacherIdStr = widget.user['id']?.toString() ?? '';
      _groups = allGroups.where((g) => g['teacher']?.toString() == teacherIdStr).toList();
    } else {
      _groups = allGroups;
    }

    List<dynamic> allStudents = [];
    if (sData is List) {
      allStudents = sData;
    } else if (sData is Map) {
      allStudents = sData['data'] ?? sData['results'] ?? [];
    }

    if (widget.user['role'] == 'teacher') {
      final teacherGroupIds = _groups.map((g) => g['id']?.toString()).whereType<String>().toList();
      _students = allStudents.where((s) {
        final sGroupIds = s['groupIds'] ?? s['groupId'];
        if (sGroupIds is List) {
          return sGroupIds.any((id) => teacherGroupIds.contains(id?.toString()));
        } else if (sGroupIds != null) {
          return teacherGroupIds.contains(sGroupIds.toString());
        }
        return false;
      }).toList();
    } else {
      _students = allStudents;
    }

    List<dynamic> allPayments = [];
    if (pData is List) {
      allPayments = pData;
    } else if (pData is Map) {
      allPayments = pData['data'] ?? pData['results'] ?? [];
    }

    if (widget.user['role'] == 'teacher') {
      final teacherGroupIds = _groups.map((g) => g['id']?.toString()).whereType<String>().toList();
      _payments = allPayments.where((p) => teacherGroupIds.contains(p['group']?.toString())).toList();
    } else {
      _payments = allPayments;
    }

    // Sort by newest first
    _payments.sort((a, b) {
      final da = a['created_at']?.toString() ?? '';
      final db = b['created_at']?.toString() ?? '';
      return db.compareTo(da);
    });
  }

  Future<void> _fetchAll() async {
    if (_payments.isEmpty) setState(() => _isLoading = true);
    try {
      final gRes = await ApiService.getGroups(widget.token);
      final sRes = await ApiService.getStudents(widget.token);
      final pRes = await ApiService.getPayments(widget.token);

      if (gRes.statusCode == 200 && sRes.statusCode == 200 && pRes.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_groups', gRes.body);
        await prefs.setString('cached_students', sRes.body);
        await prefs.setString('cached_payments', pRes.body);

        final gData = jsonDecode(gRes.body);
        final sData = jsonDecode(sRes.body);
        final pData = jsonDecode(pRes.body);

        setState(() {
          _parseAndFilter(gData, sData, pData);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeletePayment(dynamic payment) async {
    final cleanStudent = _getStudentName(payment['student']);
    final cleanAmount = _fmtFull((payment['amount'] is num)
        ? (payment['amount'] as num).toDouble()
        : double.tryParse(payment['amount'].toString()) ?? 0.0);
        
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final textColor = AppTheme.textPrimary(ctx);
        final textSecColor = AppTheme.textSecondary(ctx);

        return AlertDialog(
          backgroundColor: AppTheme.cardBg(ctx),
          title: Text('To\'lovni o\'chirish', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: Text(
            '$cleanStudent ga tegishli $cleanAmount so\'mlik to\'lovni o\'chirishni tasdiqlaysizmi?',
            style: TextStyle(color: textSecColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Bekor qilish', style: TextStyle(color: textSecColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('O\'chirish', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final pid = (payment['id'] is int)
          ? payment['id'] as int
          : int.tryParse(payment['id'].toString()) ?? 0;
      if (pid == 0) return;
      
      setState(() => _isLoading = true);
      try {
        final res = await ApiService.deletePayment(widget.token, pid);
        if (res.statusCode == 200 || res.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ To\'lov o\'chirildi'), backgroundColor: Color(0xFF00B050)),
          );
          _fetchAll();
        } else {
          setState(() => _isLoading = false);
          if (!ApiService.handleAuthError(context, res)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('O\'chirishda xatolik: ${res.body}')),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e')),
        );
      }
    }
  }

  String _getStudentName(dynamic studentId) {
    final s = _students.firstWhere(
      (s) => s['id'] == studentId || s['id'].toString() == studentId.toString(),
      orElse: () => null,
    );
    if (s == null) return 'O\'quvchi #$studentId';
    return '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
  }

  String _getGroupName(dynamic groupId) {
    final g = _groups.firstWhere(
      (g) => g['id'] == groupId || g['id'].toString() == groupId.toString(),
      orElse: () => null,
    );
    return g?['name'] ?? 'Guruh #$groupId';
  }

  void _showAddPaymentDialog() {
    int? selectedStudentId;
    int? selectedGroupId;
    final amountCtrl = TextEditingController();
    String selectedMethod = 'cash';

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    List<dynamic> studentGroups = [];    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final cardBg = AppTheme.cardBg(context);
    final border = AppTheme.border(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownColor = isDark ? const Color(0xFF0C101B) : const Color(0xFFF1F5F9);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.add_card_rounded, color: Color(0xFF00B050), size: 26),
                    const SizedBox(width: 10),
                    Text('Yangi to\'lov', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                const SizedBox(height: 20),

                // Student selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: dropdownColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: Text('O\'quvchini tanlang', style: TextStyle(color: textSecColor)),
                      value: selectedStudentId,
                      dropdownColor: cardBg,
                      style: TextStyle(color: textColor),
                      items: _students.map<DropdownMenuItem<int>>((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}', style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedStudentId = val;
                          selectedGroupId = null;
                          // Get groups of selected student
                          final student = _students.firstWhere(
                            (s) => s['id'] == val,
                            orElse: () => null,
                          );
                          if (student != null) {
                            final groupIds = student['groupIds'] ?? [];
                            studentGroups = _groups.where((g) => groupIds.contains(g['id'])).toList();
                            if (studentGroups.length == 1) selectedGroupId = studentGroups[0]['id'];
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Group selector
                if (studentGroups.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: dropdownColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        hint: Text('Guruhni tanlang', style: TextStyle(color: textSecColor)),
                        value: selectedGroupId,
                        dropdownColor: cardBg,
                        style: TextStyle(color: textColor),
                        items: studentGroups.map<DropdownMenuItem<int>>((g) {
                          return DropdownMenuItem<int>(
                            value: g['id'] as int,
                            child: Text(g['name'] ?? '', style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedGroupId = val),
                      ),
                    ),
                  ),
                if (studentGroups.length > 1) const SizedBox(height: 10),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Summa (so\'m)',
                    labelStyle: TextStyle(color: textSecColor),
                    prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF00B050)),
                    filled: true,
                    fillColor: dropdownColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00B050), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Method
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
                              color: selectedMethod == m['val'] ? const Color(0xFF00B050) : dropdownColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selectedMethod == m['val'] ? const Color(0xFF00B050) : border),
                            ),
                            child: Column(
                              children: [
                                Icon(m['icon'] as IconData, color: selectedMethod == m['val'] ? Colors.white : textSecColor, size: 18),
                                const SizedBox(height: 2),
                                Text(
                                  m['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: selectedMethod == m['val'] ? Colors.white : textSecColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
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
                      if (amount == null || selectedStudentId == null || selectedGroupId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Barcha maydonlarni to\'ldiring')),
                        );
                        return;
                      }
                      try {
                        final res = await ApiService.createPayment(widget.token, {
                          'student': selectedStudentId,
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
                            const SnackBar(content: Text('✅ To\'lov saqlandi'), backgroundColor: Color(0xFF00B050)),
                          );
                          _fetchAll();
                        } else {
                          if (!ApiService.handleAuthError(context, res)) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: ${res.body}')));
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))));

    // Today's total
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    double todayTotal = 0;
    for (final p in _payments) {
      final createdAt = p['created_at']?.toString() ?? '';
      if (createdAt.startsWith(todayStr)) {
        final a = (p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount'].toString()) ?? 0;
        todayTotal += a;
      }
    }
    final bool isAdmin = widget.user['role'] == 'admin' || widget.user['role'] == 'superadmin';
    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
        // Today summary
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00B050), Color(0xFF00873C)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B050).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.today_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Bugun tushgan', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(_fmtFull(todayTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ThreeDContainer(
                height: 80,
                width: 80,
                padding: const EdgeInsets.all(8),
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF00B050), size: 20),
                    const SizedBox(height: 2),
                    Text('${_payments.length}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    Text('jami', style: TextStyle(color: textSecColor, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Payments list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAll,
            color: const Color(0xFF00B050),
            child: _payments.isEmpty
                ? Center(child: Text('To\'lov mavjud emas', style: TextStyle(color: textSecColor)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 125),
                    itemCount: _payments.length,
                    itemBuilder: (ctx, i) {
                      final p = _payments[i];
                      final amount = (p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount'].toString()) ?? 0.0;
                      final isNegative = amount < 0;
                      final studentName = _getStudentName(p['student']);
                      final groupName = _getGroupName(p['group']);
                      final createdAt = (p['created_at']?.toString() ?? '').split('T')[0];

                      return PremiumFadeIn(
                        duration: Duration(milliseconds: 300 + (i * 50)),
                        child: ThreeDContainer(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          border: Border.all(
                            color: isNegative
                                ? Colors.redAccent.withOpacity(0.3)
                                : const Color(0xFF00B050).withOpacity(0.2),
                            width: 1,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isNegative ? Colors.redAccent.withOpacity(0.15) : const Color(0xFF00B050).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isNegative ? Icons.remove_circle_outline : Icons.payments_rounded,
                                  color: isNegative ? Colors.redAccent : const Color(0xFF00B050),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                    const SizedBox(height: 2),
                                    Text(groupName, style: TextStyle(color: textSecColor, fontSize: 12)),
                                    Text(createdAt, style: TextStyle(color: textSecColor.withOpacity(0.7), fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isNegative ? '' : '+'}${_fmtFull(amount)} so\'m',
                                    style: TextStyle(
                                      color: isNegative ? Colors.redAccent : const Color(0xFF00B050),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (widget.user['role'] == 'admin' || widget.user['role'] == 'superadmin') ...[
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => _confirmDeletePayment(p),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00B050),
              onPressed: _showAddPaymentDialog,
              child: const Icon(Icons.add_card_rounded, color: Colors.white),
            )
          : null,
    );
  }

  String _fmtFull(double amount) {
    final val = amount.toInt().abs();
    final str = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return amount < 0 ? '-${buffer.toString()}' : buffer.toString();
  }
}
