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
  } }

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
      debugPrint('Error fetching staff group messages: $e');
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
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
      }
    } catch (e) {
      debugPrint('Error sending staff group message: $e');
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
                                        InkWell(
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
                        onPressed: _pickFile,
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
