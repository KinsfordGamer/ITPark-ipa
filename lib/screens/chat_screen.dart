import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const ChatScreen({Key? key, required this.token, required this.user}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<dynamic> _messages = [];
  final Map<int, Map<String, dynamic>> _usersMap = {};
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;
  int? _lastScrollMessageCount;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchUsers();
    await _fetchMessages(isInitial: true);
    
    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom(force: true);
    }

    // Start polling every 4 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchMessages();
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
        if (mounted) setState(() {});
      } else {
        ApiService.handleAuthError(context, res);
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> _fetchMessages({bool isInitial = false}) async {
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

        // Filter out student direct messages: starting with [student_id:
        final filteredMessages = rawMessages.where((m) {
          final text = m['text']?.toString() ?? '';
          return !text.startsWith('[student_id:');
        }).toList();

        // Sort messages by id or created_at in ascending order (older first)
        filteredMessages.sort((a, b) {
          final idA = a['id'] ?? 0;
          final idB = b['id'] ?? 0;
          return idA.compareTo(idB);
        });

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(filteredMessages);
          });

          // Scroll to bottom if new messages arrived
          if (isInitial || _lastScrollMessageCount == null || _messages.length > _lastScrollMessageCount!) {
            _scrollToBottom();
            _lastScrollMessageCount = _messages.length;
          }
        }
      } else {
        ApiService.handleAuthError(context, res);
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (force) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    try {
      final res = await ApiService.sendMessage(widget.token, text);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchMessages();
        _scrollToBottom();
      } else {
        if (!ApiService.handleAuthError(context, res)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xabar yuborishda xato: ${res.body}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarmoq xatoligi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _getUserName(int? id) {
    if (id == null) return "Noma'lum xodim";
    if (id == widget.user['id']) {
      final first = widget.user['firstName'] ?? '';
      final last = widget.user['lastName'] ?? '';
      return '$first $last'.trim();
    }
    final u = _usersMap[id];
    if (u != null) {
      final first = u['first_name'] ?? '';
      final last = u['last_name'] ?? '';
      return '$first $last'.trim();
    }
    return "Xodim #$id";
  }

  String _getUserRole(int? id) {
    if (id == null) return '';
    if (id == widget.user['id']) {
      final role = widget.user['role']?.toString().toLowerCase();
      return role == 'admin' || role == 'superadmin' ? 'Admin' : 'O\'qituvchi';
    }
    final u = _usersMap[id];
    if (u != null) {
      final role = u['role']?.toString().toLowerCase();
      return role == 'admin' || role == 'superadmin' ? 'Admin' : (u['subject'] ?? 'O\'qituvchi');
    }
    return '';
  }

  Widget _getUserAvatar(dynamic avatar, String initials, {bool isMe = false}) {
    if (avatar != null && avatar.toString().startsWith('data:image/') && avatar.toString().contains(';base64,')) {
      try {
        final base64Content = avatar.toString().split(';base64,').last;
        return CircleAvatar(
          radius: 16,
          backgroundImage: MemoryImage(base64Decode(base64Content)),
        );
      } catch (_) {}
    }
    final primaryColor = const Color(0xFF00B050);
    return CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? primaryColor.withOpacity(0.2) : primaryColor,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isMe ? primaryColor : Colors.white,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00B050);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              radius: 18,
              child: const Icon(Icons.forum_rounded, color: Color(0xFF00B050), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Umumiy Xodimlar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Markaz adminlari va o\'qituvchilari guruhi',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        elevation: 0.5,
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
                                Icons.chat_bubble_outline_rounded,
                                size: 64,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Guruhda xabarlar yo\'q.\nBirinchi bo\'lib yozing!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, idx) {
                            final m = _messages[idx];
                            final senderId = m['sender_user'] ?? m['senderUser'];
                            final isMe = senderId == widget.user['id'];
                            
                            final name = _getUserName(senderId);
                            final role = _getUserRole(senderId);
                            final initials = _getInitials(name);
                            final time = _formatTime(m['created_at'] ?? m['createdAt']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    _getUserAvatar(_usersMap[senderId]?['avatar'], initials, isMe: false),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                                if (role.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white12 : Colors.black12,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      role,
                                                      style: TextStyle(fontSize: 8, color: isDark ? Colors.white60 : Colors.black54),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? primaryColor
                                                : (isDark ? const Color(0xFF161F30) : Colors.white),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(12),
                                              topRight: const Radius.circular(12),
                                              bottomLeft: Radius.circular(isMe ? 12 : 2),
                                              bottomRight: Radius.circular(isMe ? 2 : 12),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              )
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                m['text'] ?? '',
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                time,
                                                style: TextStyle(
                                                  color: isMe ? Colors.white60 : Colors.grey,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    _getUserAvatar(widget.user['avatar'], initials, isMe: true),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F30) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Xabar yozing...',
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
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Color(0xFF00B050), strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF00B050)),
                                onPressed: _sendMessage,
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
