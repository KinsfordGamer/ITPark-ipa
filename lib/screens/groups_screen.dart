import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../main.dart';

class GroupsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const GroupsScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _groups = [];
  List<dynamic> _allStudents = [];
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
    List<dynamic> allGroups = [];
    if (data is List) {
      allGroups = data;
    } else if (data is Map) {
      allGroups = data['data'] ?? data['results'] ?? [];
    }

    List<dynamic> allStudents = [];
    if (sData is List) {
      allStudents = sData;
    } else if (sData is Map) {
      allStudents = sData['data'] ?? sData['results'] ?? [];
    }
    _allStudents = allStudents;

    // Filter groups for teacher role
    if (widget.user['role'] == 'teacher') {
      final String teacherIdStr = widget.user['id']?.toString() ?? '';
      allGroups = allGroups.where((g) => g['teacher']?.toString() == teacherIdStr).toList();
    }

    _groups = allGroups;
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
      }
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showGroupDetail(Map<String, dynamic> group) {
    final List<dynamic> studentIds = group['studentIds'] ?? group['students'] ?? [];
    final List<dynamic> groupStudents = studentIds.map((id) {
      return _allStudents.firstWhere(
        (s) => s['id']?.toString() == id?.toString(),
        orElse: () => null,
      );
    }).where((s) => s != null).toList();

    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final cardBg = AppTheme.cardBg(context);
    final border = AppTheme.border(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B050).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Color(0xFF00B050)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group['name'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text('${group['price'] != null ? _fmt(group['price']) : '0'} so\'m/oy', style: TextStyle(color: textSecColor, fontSize: 13)),
                      ],
                    ),
                  ),
                   IconButton(
                    icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showGroupRating(group, groupStudents);
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00B050), size: 28),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TeacherGroupChatScreen(
                            token: widget.token,
                            groupId: group['id'],
                            groupName: group['name'] ?? 'Guruh chat',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _groupBadge(group['schedule'] ?? '—', Icons.schedule_rounded),
                  const SizedBox(width: 8),
                  if (group['activated_at'] != null)
                    _groupBadge('${group['activated_at']}'.substring(0, 10), Icons.calendar_today_rounded),
                ],
              ),
            ),
            Divider(color: border, height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.people_rounded, size: 16, color: textSecColor),
                  const SizedBox(width: 6),
                  Text('O\'quvchilar', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupStudents.length,
                itemBuilder: (ctx, i) {
                  final s = groupStudents[i];
                  final String rawName = '${s['first_name'] ?? s['firstName'] ?? ''} ${s['last_name'] ?? s['lastName'] ?? ''}'.trim();
                  
                  // Clean name if prefixed with ID e.g., "10050 - Alibek" -> "Alibek"
                  final cleanName = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF00B050).withOpacity(0.15),
                      child: Text(
                        cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF00B050), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(cleanName, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: s['phone'] != null
                        ? Text(s['phone'], style: TextStyle(color: textSecColor, fontSize: 12))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupRating(Map<String, dynamic> group, List<dynamic> students) {
    DateTime ratingDate = DateTime.now();
    final Map<int, int> tempStars = {};

    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);
    final border = AppTheme.border(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ratingCtx, setRatingState) {
          final dateStr = "${ratingDate.year}-${ratingDate.month.toString().padLeft(2, '0')}-${ratingDate.day.toString().padLeft(2, '0')}";
          
          Future<void> saveTempStars(int sid, int stars) async {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('student_stars_${sid}_date_$dateStr', stars);
              setRatingState(() {
                tempStars[sid] = stars;
              });
            } catch (_) {}
          }

          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: FutureBuilder<void>(
              future: SharedPreferences.getInstance().then((prefs) {
                for (final s in students) {
                  if (s != null) {
                    final sid = s['id'];
                    if (sid != null) {
                      tempStars[sid] = prefs.getInt('student_stars_${sid}_date_$dateStr') ?? 0;
                    }
                  }
                }
              }),
              builder: (futureCtx, snapshot) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text(
                      '${group['name'] ?? ''} — Baholash',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                          onPressed: () {
                            setRatingState(() {
                              ratingDate = ratingDate.subtract(const Duration(days: 1));
                            });
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: ratingDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: const Color(0xFF00B050),
                                      onPrimary: Colors.white,
                                      surface: AppTheme.cardBg(context),
                                      onSurface: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setRatingState(() {
                                ratingDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B050).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF00B050)),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00B050),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                          onPressed: () {
                            setRatingState(() {
                              ratingDate = ratingDate.add(const Duration(days: 1));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    students.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('Guruhda o\'quvchi yo\'q', style: TextStyle(color: textSecColor)),
                          )
                        : Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: students.length,
                              itemBuilder: (listCtx, index) {
                                final s = students[index];
                                if (s == null) return const SizedBox();
                                final rawName = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
                                final cleanName = rawName.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
                                final sid = s['id'];
                                final stars = tempStars[sid] ?? 0;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          cleanName,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(3, (starIdx) {
                                          final isFilled = starIdx < stars;
                                          return GestureDetector(
                                            onTap: () {
                                              if (sid != null) {
                                                if (stars == starIdx + 1) {
                                                  saveTempStars(sid, 0);
                                                } else {
                                                  saveTempStars(sid, starIdx + 1);
                                                }
                                              }
                                            },
                                            child: Icon(
                                              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                              color: Colors.amber,
                                              size: 24,
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B050),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tayyor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              }
            ),
          );
        },
      ),
    );
  }

  int _groupStudentCount(dynamic group) {
    final List<dynamic> studentIds = group['studentIds'] ?? group['students'] ?? [];
    return studentIds.length;
  }

  Widget _groupBadge(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12)),
        ],
      ),
    );
  }

  Color _groupColor(int index) {
    final colors = [
      const Color(0xFF00B050),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))));

    return RefreshIndicator(
      onRefresh: _fetchGroups,
      color: const Color(0xFF00B050),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 125),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final color = _groupColor(index);
          final studentCount = _groupStudentCount(group);
          final isTest = (group['name'] ?? '').toString().toLowerCase().contains('test');

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = AppTheme.textPrimary(context);
          final textSecColor = AppTheme.textSecondary(context);

          return PremiumFadeIn(
            duration: Duration(milliseconds: 300 + (index * 60)),
            child: ThreeDContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              onTap: () => _showGroupDetail(group),
              border: Border(
                left: BorderSide(color: color, width: 4),
                top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                right: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              group['name'] ?? '',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            if (isTest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('TEST', style: TextStyle(fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(group['schedule'] ?? '—', style: TextStyle(color: textSecColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_fmt(group['price'])} so\'m',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_rounded, size: 12, color: textSecColor),
                          const SizedBox(width: 4),
                          Text('$studentCount ta', style: TextStyle(color: textSecColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: textSecColor.withOpacity(0.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(dynamic amount) {
    final val = (amount is num) ? amount.toInt() : int.tryParse(amount.toString()) ?? 0;
    final str = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class TeacherGroupChatScreen extends StatefulWidget {
  final String token;
  final int groupId;
  final String groupName;

  const TeacherGroupChatScreen({
    Key? key,
    required this.token,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _TeacherGroupChatScreenState createState() => _TeacherGroupChatScreenState();
}

class _TeacherGroupChatScreenState extends State<TeacherGroupChatScreen> {
  final List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollingTimer;

  // File variables
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await ApiService.getStaffGroupMessages(widget.token, widget.groupId);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(data);
            _isLoading = false;
          });
          if (!silent) {
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching group messages: $e');
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _pickFileWithType(FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: type);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _showAttachmentMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161F30) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Biriktirish',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _attachmentOption(
                      icon: Icons.image_rounded,
                      color: Colors.purple,
                      label: 'Galereya',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFileWithType(FileType.image);
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.video_collection_rounded,
                      color: Colors.pink,
                      label: 'Video',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFileWithType(FileType.video);
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      color: Colors.blue,
                      label: 'Fayl',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFileWithType(FileType.any);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFile() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _selectedFilePath == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final res = await ApiService.sendStaffGroupMessageWithFile(
        widget.token,
        widget.groupId,
        text,
        _selectedFilePath,
        _selectedFileName,
      );
      final responseBody = await res.stream.bytesToString();
      if (res.statusCode == 200 || res.statusCode == 201) {
        _msgCtrl.clear();
        _clearFile();
        await _fetchMessages(silent: true);
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $responseBody (Status: ${res.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending staff group message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ulanish xatoligi: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _downloadAndOpenFile(String fileUrl, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fayl ochilmoqda: $fileName...')),
      );
      String fullUrl = fileUrl;
      if (!fileUrl.startsWith('http')) {
        fullUrl = 'https://itparksurhondaryocrm.one' + fileUrl;
      }
      
      final res = await http.get(Uri.parse(fullUrl));
      if (res.statusCode == 200) {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(res.bodyBytes);
        await OpenFile.open(file.path);
      } else {
        throw Exception('File download failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faylni ochishda xatolik yuz berdi')),
      );
    }
  }

  bool _isImage(String? fileUrl) {
    if (fileUrl == null) return false;
    final path = fileUrl.toLowerCase();
    final cleanPath = path.split('?').first;
    return cleanPath.endsWith('.png') ||
        cleanPath.endsWith('.jpg') ||
        cleanPath.endsWith('.jpeg') ||
        cleanPath.endsWith('.gif') ||
        cleanPath.endsWith('.webp') ||
        path.contains('.png') ||
        path.contains('.jpg') ||
        path.contains('.jpeg') ||
        path.contains('.webp') ||
        path.contains('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00B050);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: isDark ? const Color(0xFF131C2E) : primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B050)))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_work_outlined,
                                size: 64,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Bu guruhda xabarlar yo\'q.\nDarslar va savollaringiz haqida yozing!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final m = _messages[i];
                            final isMe = m['isFromMe'] == true;
                            final senderName = m['sender'] ?? 'Tizim';
                            final time = m['createdAt'] != null
                                ? m['createdAt'].toString().split('T').last.substring(0, 5)
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? primaryColor
                                        : (isDark ? const Color(0xFF131C2E) : Colors.grey[200]),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 2),
                                      bottomRight: Radius.circular(isMe ? 2 : 16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isMe)
                                        Text(
                                          senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      if (!isMe) const SizedBox(height: 4),
                                      if (m['text'] != null && m['text'].toString().isNotEmpty)
                                        Text(
                                          m['text'],
                                          style: TextStyle(
                                            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                            fontSize: 14,
                                          ),
                                        ),
                                      if (m['file'] != null) ...[
                                        const SizedBox(height: 8),
                                        Builder(
                                          builder: (context) {
                                            final fileUrl = m['file'].toString();
                                            String fullUrl = fileUrl;
                                            if (!fileUrl.startsWith('http')) {
                                              fullUrl = 'https://itparksurhondaryocrm.one' + fileUrl;
                                            }

                                            if (_isImage(fileUrl)) {
                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => CustomImageViewerScreen(
                                                        imageUrl: fullUrl,
                                                        fileName: m['fileName'] ?? 'Rasm',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    fullUrl,
                                                    fit: BoxFit.cover,
                                                    width: 220,
                                                    height: 160,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        width: 220,
                                                        height: 160,
                                                        color: Colors.black12,
                                                        child: const Center(
                                                          child: CircularProgressIndicator(color: Color(0xFF00B050), strokeWidth: 2),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        width: 220,
                                                        height: 160,
                                                        color: Colors.black12,
                                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              );
                                            }

                                            return InkWell(
                                              onTap: () => _downloadAndOpenFile(m['file'], m['fileName'] ?? 'fayl'),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.insert_drive_file, color: Colors.amber, size: 20),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        m['fileName'] ?? 'Faylni ochish',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            color: isMe ? Colors.white60 : Colors.white38,
                                            fontSize: 9,
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
                if (_selectedFileName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black38,
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: _clearFile,
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: isDark ? const Color(0xFF131C2E) : Colors.grey[100],
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
                        onPressed: () => _showAttachmentMenu(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Xabar yozing...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      _isSending
                          ? const CircularProgressIndicator(color: Color(0xFF00B050))
                          : IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFF00B050)),
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

class CustomImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String fileName;

  const CustomImageViewerScreen({Key? key, required this.imageUrl, required this.fileName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          clipBehavior: Clip.none,
          maxScale: 4.0,
          minScale: 0.5,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator(color: Color(0xFF00B050));
            },
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 64),
          ),
        ),
      ),
    );
  }
}
