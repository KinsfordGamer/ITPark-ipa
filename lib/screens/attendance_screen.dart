import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../main.dart';

class AttendanceScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const AttendanceScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _groups = [];
  List<dynamic> _allStudents = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedGroup;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _students = [];
  Map<int, String> _attendanceMap = {};
  final Map<int, int> _starsMap = {};
  bool _isSaving = false;
  bool _isLoadingStudents = false;

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
      final cachedG = prefs.getString('cached_groups');
      final cachedS = prefs.getString('cached_students');
      if (cachedG != null && cachedS != null) {
        final data = jsonDecode(cachedG);
        final sData = jsonDecode(cachedS);
        _parseAndFilter(data, sData);
        setState(() => _isLoading = false);
      }
    } catch (_) {}
    _fetchGroups();
  }

  void _parseAndFilter(dynamic data, dynamic sData) {
    List<dynamic> all = [];
    if (data is List) {
      all = data;
    } else if (data is Map) {
      all = data['data'] ?? data['results'] ?? [];
    }
    
    List<dynamic> allStudents = [];
    if (sData is List) {
      allStudents = sData;
    } else if (sData is Map) {
      allStudents = sData['data'] ?? sData['results'] ?? [];
    }
    _allStudents = allStudents;
    
    // Remove test groups
    all = all.where((g) => !(g['name'] ?? '').toString().toLowerCase().contains('test')).toList();

    // If teacher, filter groups
    if (widget.user['role'] == 'teacher') {
      final String teacherIdStr = widget.user['id']?.toString() ?? '';
      all = all.where((g) => g['teacher']?.toString() == teacherIdStr).toList();
    }

    _groups = all;
  }

  Future<void> _fetchGroups() async {
    if (_groups.isEmpty) setState(() => _isLoading = true);
    try {
      final res = await ApiService.getGroups(widget.token);
      final sRes = await ApiService.getStudents(widget.token);
      
      if (res.statusCode == 200 && sRes.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_groups', res.body);
        await prefs.setString('cached_students', sRes.body);

        final data = jsonDecode(res.body);
        final sData = jsonDecode(sRes.body);
        
        setState(() {
          _parseAndFilter(data, sData);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (ApiService.handleAuthError(context, res)) return;
        if (ApiService.handleAuthError(context, sRes)) return;
      }
    } catch (e) {
      debugPrint('Error fetching attendance groups: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectGroup(Map<String, dynamic> group) async {
    setState(() {
      _selectedGroup = group;
      _students = [];
      _attendanceMap = {};
      _starsMap.clear();
      _isLoadingStudents = true;
    });

    // Get studentIds from group
    final List<dynamic> studentIds = group['studentIds'] ?? group['students'] ?? [];
    
    // Map IDs to student objects from _allStudents
    final List<dynamic> studentList = studentIds.map((id) {
      return _allStudents.firstWhere(
        (s) => s['id']?.toString() == id?.toString(),
        orElse: () => null,
      );
    }).where((s) => s != null).toList();

    // Load existing attendance for this date and group
    final dateStr = _formatDate(_selectedDate);
    try {
      final res = await ApiService.getAttendanceRecords(
        widget.token,
        groupId: group['id'],
        date: dateStr,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> records = data['data'] ?? data['results'] ?? data;
        for (final r in records) {
          final sid = r['student'];
          if (sid != null) {
            _attendanceMap[sid] = r['status'] ?? 'kelmadi';
            _starsMap[sid] = r['stars_given'] ?? r['stars'] ?? 0;
          }
        }
      }
    } catch (_) {}

    setState(() {
      _students = studentList;
      _isLoadingStudents = false;
      // Default all to 'keldi'
      for (final s in _students) {
        final sid = s['id'];
        if (sid != null && !_attendanceMap.containsKey(sid)) {
          _attendanceMap[sid] = 'keldi';
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00B050)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (_selectedGroup != null) _selectGroup(_selectedGroup!);
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedGroup == null || _students.isEmpty) return;
    setState(() => _isSaving = true);

    final dateStr = _formatDate(_selectedDate);
    final groupId = _selectedGroup!['id'];

    final records = _students.map((s) {
      final sid = s['id'];
      return {
        'student': sid,
        'group': groupId,
        'date': dateStr,
        'status': _attendanceMap[sid] ?? 'kelmadi',
        'stars': _starsMap[sid] ?? 0,
      };
    }).toList();

    try {
      final res = await ApiService.bulkSaveAttendance(widget.token, records);
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Davomat saqlandi!'),
            backgroundColor: Color(0xFF00B050),
          ),
        );

        // Generate SMS records for absent students
        try {
          final prefs = await SharedPreferences.getInstance();
          final List<String> existingLogs = prefs.getStringList('scheduled_sms_logs') ?? [];
          
          for (final s in _students) {
            final status = _attendanceMap[s['id']];
            if (status == 'kelmadi') {
              final rawName = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
              final cleanName = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
              final phone = s['phone'] ?? '';
              
              // Prevent duplicates for the same student on the same day
              final isDuplicate = existingLogs.any((logStr) {
                final log = jsonDecode(logStr);
                return log['studentName'] == cleanName && log['date'] == dateStr;
              });

              if (!isDuplicate) {
                final logEntry = {
                  'id': 'sms_${DateTime.now().millisecondsSinceEpoch}_${s['id']}',
                  'studentName': cleanName,
                  'phone': phone,
                  'date': dateStr,
                  'scheduledTime': '21:00',
                  'message': 'Hurmatli ota-ona! $cleanName bugun IT Park darsiga qatnashmadi.',
                  'status': 'Kutilmoqda',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };
                existingLogs.add(jsonEncode(logEntry));
              }
            }
          }
          await prefs.setStringList('scheduled_sms_logs', existingLogs);
        } catch (e) {
          debugPrint('Error generating SMS cache: $e');
        }
      } else {
        if (!ApiService.handleAuthError(context, res)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xato: ${res.body}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    }
    setState(() => _isSaving = false);
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _statusButton(int studentId, String status, String label, Color color) {
    final isSelected = _attendanceMap[studentId] == status;
    return GestureDetector(
      onTap: () => setState(() => _attendanceMap[studentId] = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : color.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        )),
      ),
    );
  }  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))));

    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Top controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              // Date picker
              PremiumFadeIn(
                duration: const Duration(milliseconds: 300),
                child: ThreeDContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: EdgeInsets.zero,
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Color(0xFF00B050), size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _formatDate(_selectedDate),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                      ),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_down_rounded, color: textSecColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Group selector
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final g = _groups[i];
                    final isSelected = _selectedGroup?['id'] == g['id'];
                    return GestureDetector(
                      onTap: () => _selectGroup(g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00B050) : AppTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected ? const Color(0xFF00B050) : AppTheme.border(context)),
                        ),
                        child: Text(
                          g['name'] ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Student attendance list
        Expanded(
          child: _selectedGroup == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 60, color: textSecColor.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('Guruhni tanlang', style: TextStyle(color: textSecColor, fontSize: 16)),
                    ],
                  ),
                )
              : _isLoadingStudents
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B050)))
                  : _students.isEmpty
                      ? Center(child: Text('Bu guruhda o\'quvchi yo\'q', style: TextStyle(color: textSecColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 125),
                          itemCount: _students.length,
                          itemBuilder: (ctx, i) {
                            final s = _students[i];
                            final int? sid = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '');
                            if (sid == null) return const SizedBox();
                            final rawName = '${s['first_name'] ?? s['firstName'] ?? ''} ${s['last_name'] ?? s['lastName'] ?? ''}';
                            final name = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), ''); // Clean ID prefix
                            final status = _attendanceMap[sid] ?? 'keldi';

                            Color statusColor;
                            switch (status) {
                              case 'keldi': statusColor = const Color(0xFF00B050); break;
                              case 'kelmadi': statusColor = Colors.redAccent; break;
                              case 'kechikdi': statusColor = Colors.orangeAccent; break;
                              default: statusColor = Colors.blueAccent;
                            }

                            return PremiumFadeIn(
                              duration: Duration(milliseconds: 300 + (i * 50)),
                              child: ThreeDContainer(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: Border.all(color: statusColor.withOpacity(0.25)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: statusColor.withOpacity(0.15),
                                          child: Text(
                                            '${i + 1}', // Tartib raqami
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(3, (starIdx) {
                                            final stars = _starsMap[sid] ?? 0;
                                            final isFilled = starIdx < stars;
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (stars == starIdx + 1) {
                                                    _starsMap[sid] = 0;
                                                  } else {
                                                    _starsMap[sid] = starIdx + 1;
                                                  }
                                                });
                                              },
                                              child: Icon(
                                                isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                                color: Colors.amber,
                                                size: 20,
                                              ),
                                            );
                                          }),
                                        ),
                                        const Spacer(),
                                        _statusButton(sid, 'keldi', 'Keldi', const Color(0xFF00B050)),
                                        const SizedBox(width: 6),
                                        _statusButton(sid, 'kelmadi', 'Kelmadi', Colors.redAccent),
                                        const SizedBox(width: 6),
                                        _statusButton(sid, 'kechikdi', 'Kech', Colors.orangeAccent),
                                        const SizedBox(width: 6),
                                        _statusButton(sid, 'sababli', 'Sababli', Colors.blueAccent),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Save button
        if (_selectedGroup != null && _students.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 125),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B050),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _saveAttendance,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Saqlash (${_students.length} ta o\'quvchi)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
