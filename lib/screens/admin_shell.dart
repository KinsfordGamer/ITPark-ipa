import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'groups_screen.dart';
import 'attendance_screen.dart';
import 'payments_screen.dart';
import 'chat_screen.dart';
import '../services/notification_service.dart';

import 'package:flutter/services.dart';

class AdminShell extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const AdminShell({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _AdminShellState createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  late PageController _pageController;
  Timer? _smsProcessorTimer;
  Timer? _chatPollingTimer;
  final Set<int> _knownMessageIds = {};
  bool _isFirstChatPoll = true;
  final Map<int, Map<String, dynamic>> _usersMap = {};
  bool _isDragging = false;

  void _handleDragUpdate(double localX, double tabWidth, int numTabs) {
    int index = (localX / tabWidth).floor().clamp(0, numTabs - 1);
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      HapticFeedback.selectionClick();
      _pageController.jumpToPage(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _startSmsProcessor();
    _startChatPolling();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _smsProcessorTimer?.cancel();
    _chatPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await ApiService.clearAdminToken();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String get _role => widget.user['role'] ?? 'teacher';
  bool get _isAdmin => _role == 'admin' || _role == 'superadmin';

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(token: widget.token, user: widget.user),
      StudentsScreen(token: widget.token, user: widget.user),
      GroupsScreen(token: widget.token, user: widget.user),
      AttendanceScreen(token: widget.token, user: widget.user),
      PaymentsScreen(token: widget.token, user: widget.user),
    ];

    final String roleName = _isAdmin ? 'Admin' : 'O\'qituvchi';
    final String fullName = '${widget.user['firstName'] ?? ''} ${widget.user['lastName'] ?? ''}'.trim();

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00B050),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IT PARK CRM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary(context))),
                Text(roleName, style: const TextStyle(fontSize: 11, color: Color(0xFF00B050))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.forum_outlined, color: AppTheme.textPrimary(context)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(token: widget.token, user: widget.user),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_active_outlined, color: AppTheme.textPrimary(context)),
            onPressed: _showSmsInboxModal,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ITParkApp.themeNotifier,
            builder: (_, ThemeMode currentMode, __) {
              final isLight = currentMode == ThemeMode.light;
              return IconButton(
                icon: Icon(
                  isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isLight ? Colors.black54 : Colors.yellowAccent,
                ),
                onPressed: () async {
                  final newMode = isLight ? ThemeMode.dark : ThemeMode.light;
                  ITParkApp.themeNotifier.value = newMode;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_light_theme', newMode == ThemeMode.light);
                },
              );
            },
          ),
          const SizedBox(width: 4),
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF00B050),
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            color: AppTheme.cardBg(context),
            itemBuilder: (ctx) => <PopupMenuEntry<dynamic>>[
              PopupMenuItem<dynamic>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                    Text(roleName, style: const TextStyle(fontSize: 12, color: Color(0xFF00B050))),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<dynamic>(
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Chiqish', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth - 32;
            final int numTabs = 5;
            final double tabWidth = (totalWidth - 16) / numTabs;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isDragging = true;
                });
                _handleDragUpdate(details.localPosition.dx, tabWidth, numTabs);
              },
              onPanUpdate: (details) {
                _handleDragUpdate(details.localPosition.dx, tabWidth, numTabs);
              },
              onPanEnd: (_) {
                setState(() {
                  _isDragging = false;
                });
              },
              onPanCancel: () {
                setState(() {
                  _isDragging = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.fromLTRB(16, 0, 16, _isDragging ? 24 : 16),
                height: 70,
                transform: Matrix4.identity()
                  ..translate(0.0, _isDragging ? -6.0 : 0.0)
                  ..scale(_isDragging ? 1.04 : 1.0),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg(context).withOpacity(_isDragging ? 0.88 : 0.94),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isDragging 
                        ? AppTheme.accentColor.withOpacity(0.35)
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                    width: _isDragging ? 1.6 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.35) : Colors.grey.withOpacity(0.12),
                      blurRadius: _isDragging ? 22 : 18,
                      offset: Offset(0, _isDragging ? 12 : 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: ((_currentIndex * tabWidth) + 8),
                          width: tabWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.accentColor.withOpacity(0.35),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildNavItem(0, Icons.dashboard_rounded, 'Bosh sahifa')),
                            Expanded(child: _buildNavItem(1, Icons.people_rounded, 'O\'quvchilar')),
                            Expanded(child: _buildNavItem(2, Icons.groups_rounded, 'Guruhlar')),
                            Expanded(child: _buildNavItem(3, Icons.fact_check_rounded, 'Davomat')),
                            Expanded(child: _buildNavItem(4, Icons.payments_rounded, 'To\'lovlar')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final activeColor = AppTheme.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected ? activeColor : (isDark ? Colors.white38 : Colors.black45),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : (isDark ? Colors.white38 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInAppNotification(String title, String body) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (ctx, offset, child) {
              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00B050), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B050).withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B050).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_rounded, color: Color(0xFF00B050), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () => entry.remove(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    Timer(const Duration(seconds: 5), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  void _startSmsProcessor() {
    _smsProcessorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> logStrings = prefs.getStringList('scheduled_sms_logs') ?? [];
        if (logStrings.isEmpty) return;

        bool updated = false;
        final List<String> updatedLogs = [];
        
        final now = DateTime.now();
        // Check if current hour is past 21 (9:00 PM)
        final isPastNinePM = now.hour >= 21;

        for (final logStr in logStrings) {
          final log = jsonDecode(logStr);
          if (log['status'] == 'Kutilmoqda' && isPastNinePM) {
            log['status'] = 'Yuborildi';
            updated = true;
            _showInAppNotification(
              'IT Park SMS Service',
              'Hurmatli ota-ona! ${log['studentName']} bugun IT Park darsiga qatnashmadi.',
            );
          }
          updatedLogs.add(jsonEncode(log));
        }

        if (updated) {
          await prefs.setStringList('scheduled_sms_logs', updatedLogs);
        }
      } catch (e) {
        debugPrint('Error processing scheduled SMS: $e');
      }
    });
  }

  void _startChatPolling() async {
    await _fetchUsers();
    _pollChatMessages();
    
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _pollChatMessages();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final res = await ApiService.getUsers(widget.token);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> users = [];
        if (decoded is List) {
          users = decoded;
        } else if (decoded is Map) {
          users = decoded['results'] ?? decoded['data'] ?? [];
        }

        for (final u in users) {
          final id = u['id'];
          if (id != null && id is int) {
            _usersMap[id] = u;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching users in shell: $e');
    }
  }

  Future<void> _pollChatMessages() async {
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

        final groupMessages = rawMessages.where((m) {
          final text = m['text']?.toString() ?? '';
          return !text.startsWith('[student_id:');
        }).toList();

        for (final m in groupMessages) {
          final id = m['id'];
          if (id != null && id is int) {
            if (!_knownMessageIds.contains(id)) {
              _knownMessageIds.add(id);
              
              final senderId = m['sender_user'] ?? m['senderUser'];
              if (!_isFirstChatPoll && senderId != widget.user['id']) {
                final senderName = _getSenderName(senderId);
                final text = m['text'] ?? '';
                
                await NotificationService.showNotification(
                  'Guruh suhbati: $senderName',
                  text,
                );
                
                _showInAppNotification(
                  'Guruh suhbati: $senderName',
                  text,
                );
              }
            }
          }
        }
        
        if (_isFirstChatPoll) {
          _isFirstChatPoll = false;
        }
      }
    } catch (e) {
      debugPrint('Error polling chat messages: $e');
    }
  }

  String _getSenderName(int? id) {
    if (id == null) return "Noma'lum";
    if (id == widget.user['id']) return "Men";
    final u = _usersMap[id];
    if (u != null) {
      final first = u['first_name'] ?? '';
      final last = u['last_name'] ?? '';
      return '$first $last'.trim();
    }
    return "Xodim";
  }

  Future<void> _showSmsInboxModal() async {
    final prefs = await SharedPreferences.getInstance();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final List<String> logStrings = prefs.getStringList('scheduled_sms_logs') ?? [];
          final List<dynamic> logs = logStrings.map((s) => jsonDecode(s)).toList();
          logs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

          final textColor = AppTheme.textPrimary(ctx);
          final textSecColor = AppTheme.textSecondary(ctx);
          final border = AppTheme.border(ctx);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B050).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sms_rounded, color: Color(0xFF00B050)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('IT Park SMS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                            ],
                          ),
                          Text('SMS ogohlantirishlar tarixi', style: TextStyle(color: textSecColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (logs.any((l) => l['status'] == 'Kutilmoqda'))
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B050).withOpacity(0.2),
                          foregroundColor: const Color(0xFF00B050),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          bool updated = false;
                          final List<String> updatedLogs = [];
                          for (final log in logs) {
                            if (log['status'] == 'Kutilmoqda') {
                              log['status'] = 'Yuborildi';
                              updated = true;
                              _showInAppNotification(
                                'IT Park SMS Service',
                                'Hurmatli ota-ona! ${log['studentName']} bugun IT Park darsiga qatnashmadi.',
                              );
                            }
                            updatedLogs.add(jsonEncode(log));
                          }
                          if (updated) {
                            await prefs.setStringList('scheduled_sms_logs', updatedLogs);
                            setModalState(() {});
                          }
                        },
                        child: const Text('Test Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],  
                ),
                Divider(color: border, height: 24),
                Expanded(
                  child: logs.isEmpty
                      ? Center(
                          child: Text('Hozircha SMS yuborilmagan', style: TextStyle(color: textSecColor)),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (ctx, i) {
                            final log = logs[i];
                            final isSent = log['status'] == 'Yuborildi';
                            return ThreeDContainer(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              border: Border.all(
                                color: isSent ? border : const Color(0xFF00B050).withOpacity(0.25),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'O\'quvchi: ${log['studentName']}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSent
                                              ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                                              : const Color(0xFF00B050).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isSent ? 'Yuborildi' : 'Kutilmoqda (21:00)',
                                          style: TextStyle(
                                            color: isSent ? textSecColor : const Color(0xFF00B050),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Telefon: ${log['phone']}',
                                    style: TextStyle(color: textSecColor, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    log['message'] ?? '',
                                    style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Sana: ${log['date']}',
                                    style: TextStyle(color: textSecColor.withOpacity(0.6), fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
