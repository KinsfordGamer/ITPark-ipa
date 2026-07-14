import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'screens/admin_shell.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ITParkApp());
}

class AppTheme {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color cardBg(BuildContext context) => isDark(context) ? const Color(0xFF1E293B) : Colors.white;
  static Color darkBlueBg(BuildContext context) => isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color bottomNavBg(BuildContext context) => isDark(context) ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.9);
  static Color textPrimary(BuildContext context) => isDark(context) ? Colors.white : const Color(0xFF1E293B);
  static Color textSecondary(BuildContext context) => isDark(context) ? Colors.white54 : const Color(0xFF64748B);
  static Color border(BuildContext context) => isDark(context) ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);
  static Color accentColor = const Color(0xFF10B981); // Emerald Mint Green
  static Color secondaryColor = const Color(0xFF6366F1); // Indigo/Purple
}

class ThreeDContainer extends StatefulWidget {
  final Widget child;
  final double? height;
  final double? width;
  final Color? color;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const ThreeDContainer({
    Key? key,
    required this.child,
    this.height,
    this.width,
    this.color,
    this.gradientColors,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.borderRadius,
    this.border,
    this.onTap,
  }) : super(key: key);

  @override
  State<ThreeDContainer> createState() => _ThreeDContainerState();
}

class _ThreeDContainerState extends State<ThreeDContainer> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final defaultBorder = Border.all(
      color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.05),
      width: 1.1,
    );

    final resolvedBorder = widget.border ?? defaultBorder;
    final rRadius = widget.borderRadius ?? BorderRadius.circular(20);
    final double depth = _isPressed ? 1.5 : 8.0;
    
    final List<BoxShadow> shadows = [
      // Deep 2.5D drop shadow
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.55) : Colors.grey.withOpacity(0.18),
        offset: Offset(0, depth),
        blurRadius: _isPressed ? 4.0 : 16.0,
        spreadRadius: _isPressed ? 0.0 : -2.0,
      ),
      // Subtle green brand glow
      BoxShadow(
        color: const Color(0xFF00B050).withOpacity(isDark ? 0.04 : 0.02),
        offset: Offset(0, depth * 1.5),
        blurRadius: _isPressed ? 8.0 : 24.0,
        spreadRadius: -4,
      ),
      // Highlight reflection shadow
      if (!_isPressed)
        BoxShadow(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.85),
          offset: const Offset(0, -1.5),
          blurRadius: 3.0,
          spreadRadius: 0.5,
        ),
    ];

    // Premium 2.5D glassmorphic background gradient
    final defaultGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E2B42), Color(0xFF111927)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Colors.white, Color(0xFFF7F9FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final finalGradient = widget.gradientColors != null 
        ? LinearGradient(
            colors: widget.gradientColors!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : (widget.color != null ? null : defaultGradient);

    final finalBgColor = widget.gradientColors == null && finalGradient == null 
        ? (widget.color ?? (isDark ? const Color(0xFF161F30) : Colors.white)) 
        : null;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      height: widget.height,
      width: widget.width,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: finalBgColor,
        gradient: finalGradient,
        borderRadius: rRadius,
        border: resolvedBorder,
        boxShadow: shadows,
      ),
      transform: Matrix4.identity()
        ..scale(_isPressed ? 0.97 : 1.0)
        ..translate(0.0, _isPressed ? depth * 0.55 : -2.0), // Raise card slightly when resting
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }
}

class PremiumFadeIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const PremiumFadeIn({
    Key? key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;

  const BounceButton({
    Key? key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 100),
  }) : super(key: key);

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap!();
      },
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class ITParkApp extends StatefulWidget {
  const ITParkApp({Key? key}) : super(key: key);

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  @override
  State<ITParkApp> createState() => _ITParkAppState();
}

class _ITParkAppState extends State<ITParkApp> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isLight = prefs.getBool('is_light_theme') ?? false;
    ITParkApp.themeNotifier.value = isLight ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ITParkApp.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        final isLight = currentMode == ThemeMode.light;
        return MaterialApp(
          title: 'IT Park Surkhandaryo',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF00B050),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF00B050)),
              titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B050),
              secondary: Color(0xFF00873C),
              surface: Colors.white,
              background: const Color(0xFFF8FAFC),
              onBackground: Color(0xFF0F172A),
              onSurface: Color(0xFF1E293B),
            ),
            textTheme: const TextTheme(
              headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF334155)),
              bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF00B050),
            scaffoldBackgroundColor: const Color(0xFF0C101B),
            cardColor: const Color(0xFF161F30),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0E1524),
              foregroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF00B050)),
              titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00B050),
              secondary: Color(0xFF00E676),
              surface: Color(0xFF161F30),
              background: const Color(0xFF0C101B),
              onBackground: Colors.white,
              onSurface: Color(0xFFE2E8F0),
            ),
            textTheme: const TextTheme(
              headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFCBD5E1)),
              bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  String? _token;
  bool _isDefaultPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  String? _adminToken;
  Map<String, dynamic>? _adminUser;

  Future<void> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Check admin token first
      final adminToken = prefs.getString('admin_token');
      final adminUserStr = prefs.getString('admin_user');
      if (adminToken != null && adminUserStr != null) {
        final adminUser = jsonDecode(adminUserStr);
        if (mounted) {
          setState(() {
            _adminToken = adminToken;
            _adminUser = adminUser;
            _isLoading = false;
          });
        }
        return;
      }
      // Then check student token
      final token = prefs.getString('student_token');
      final isDefault = prefs.getBool('is_default_password') ?? false;
      if (mounted) {
        setState(() {
          _token = token;
          _isDefaultPassword = isDefault;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00B050)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('Tizimni yuklashda xatolik yuz berdi:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    // Admin/Teacher portal
    if (_adminToken != null && _adminUser != null) {
      return AdminShell(token: _adminToken!, user: _adminUser!);
    }

    // Student portal
    if (_token == null) {
      return LoginScreen(onAdminLogin: _checkAuth);
    }

    if (_isDefaultPassword) {
      return ChangePasswordScreen(
        token: _token!,
        isForced: true,
        onPasswordChanged: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_default_password', false);
          _checkAuth();
        },
      );
    }

    return MainShell(token: _token!);
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onAdminLogin;
  const LoginScreen({Key? key, required this.onAdminLogin}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Student login
  final _studentIdController = TextEditingController();
  final _studentPasswordController = TextEditingController();
  // Admin login
  final _adminPhoneController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  String _baseUrl = 'https://itparksurhondaryocrm.one/api';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _studentIdController.dispose();
    _studentPasswordController.dispose();
    _adminPhoneController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _studentLogin() async {
    final studentId = _studentIdController.text.trim();
    final password = _studentPasswordController.text.trim();
    if (studentId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID va parolni kiriting')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/student-login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_token', data['token']);
        await prefs.setBool('is_default_password', data['student']['isDefaultPassword'] ?? false);
        await prefs.setString('student_id_str', studentId);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthGate()));
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Login xatosi')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarmoq xatosi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _adminLogin() async {
    final phone = _adminPhoneController.text.trim();
    final password = _adminPasswordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefon va parolni kiriting')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.adminLogin(phone, password);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] ?? data['access'];
        final user = data['user'] ?? data;
        await ApiService.saveAdminToken(token, {
          'id': user['id'],
          'firstName': user['firstName'] ?? user['first_name'] ?? '',
          'lastName': user['lastName'] ?? user['last_name'] ?? '',
          'role': user['role'] ?? 'teacher',
          'phone': user['phone'] ?? '',
        });
        widget.onAdminLogin();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? data['detail'] ?? 'Login xatosi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarmoq xatosi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() => _studentLogin();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = AppTheme.textPrimary(context);
    final cardBgColor = AppTheme.cardBg(context);
    final inputFillColor = isDark ? const Color(0xFF0C101B) : const Color(0xFFF1F5F9);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B050),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B050).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: const Icon(Icons.school_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'IT PARK',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2, color: titleColor),
              ),
              const Text(
                'Surkhandaryo CRM',
                style: TextStyle(fontSize: 14, color: Color(0xFF00B050), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131C2E) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: const Color(0xFF00B050),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'O\'quvchi'),
                    Tab(text: 'Admin / O\'qituvchi'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // --- STUDENT TAB ---
                    _buildCard([
                      _inputField(_studentIdController, 'O\'quvchi ID si', Icons.badge, keyboardType: TextInputType.number, fillColor: inputFillColor),
                      const SizedBox(height: 14),
                      _inputField(_studentPasswordController, 'Parol', Icons.lock, obscure: true, fillColor: inputFillColor),
                      const SizedBox(height: 20),
                      _submitBtn('Kirish', _studentLogin),
                    ], cardBgColor),
                    // --- ADMIN TAB ---
                    _buildCard([
                      _inputField(_adminPhoneController, 'Telefon raqam', Icons.phone_android_rounded, keyboardType: TextInputType.phone, fillColor: inputFillColor),
                      const SizedBox(height: 14),
                      _inputField(_adminPasswordController, 'Parol', Icons.lock, obscure: true, fillColor: inputFillColor),
                      const SizedBox(height: 20),
                      _submitBtn('Tizimga kirish', _adminLogin),
                    ], cardBgColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children, Color bgColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: bgColor,
      elevation: 0,
      child: Padding(padding: const EdgeInsets.all(20), child: Column(children: children)),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboardType, required Color fillColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFF00B050)),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00B050), width: 2),
        ),
      ),
    );
  }

  Widget _submitBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B050),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  final String token;
  final bool isForced;
  final VoidCallback onPasswordChanged;

  const ChangePasswordScreen({
    Key? key,
    required this.token,
    required this.isForced,
    required this.onPasswordChanged,
  }) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _baseUrl = 'https://itparksurhondaryocrm.one/api';

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcha maydonlarni to\'ldiring')),
      );
      return;
    }

    if (newPass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parol kamida 4 belgidan iborat bo\'lishi kerak')),
      );
      return;
    }

    if (newPass != confPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parollar mos kelmadi')),
      );
      return;
    }

    if (newPass == '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, boshqa parol tanlang')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/student-portal/change-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'new_password': newPass,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parol muvaffaqiyatli o\'zgartirildi')),
        );
        widget.onPasswordChanged();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Xatolik yuz berdi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarmoq xatosi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.security_rounded,
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Parolni o\'zgartirish',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (widget.isForced)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Siz tizimga standart parol ("123456") bilan kirdingiz. Xavfsizlikni ta\'minlash uchun parolni o\'zgartirishingiz shart.',
                    style: TextStyle(color: Colors.orangeAccent, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Yangi parol',
                          prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF00B050)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Yangi parolni tasdiqlang',
                          prefixIcon: const Icon(Icons.check_circle, color: Color(0xFF00B050)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B050),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Tasdiqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final String token;

  const MainShell({Key? key, required this.token}) : super(key: key);

  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _baseUrl = 'https://itparksurhondaryocrm.one/api';
  Timer? _notificationCheckTimer;
  Set<int> _seenMessageIds = {};
  String _lastWarningState = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startNotificationListener();
  }

  @override
  void dispose() {
    _notificationCheckTimer?.cancel();
    _tooltipTimer?.cancel();
    super.dispose();
  }

  void _startNotificationListener() {
    NotificationService.checkAndRequestPermissions();
    _notificationCheckTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      await NotificationService.checkAndRequestPermissions();
      _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    try {
      final res = await ApiService.getStudentMessages(widget.token);
      if (res.statusCode == 200) {
        final List<dynamic> messages = jsonDecode(res.body);
        if (messages.isEmpty) return;

        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getStringList('seen_msg_ids') ?? [];
        final storedIds = stored.map((s) => int.tryParse(s)).whereType<int>().toSet();
        _seenMessageIds.addAll(storedIds);

        // Check for new messages
        bool hasNew = false;
        for (final m in messages) {
          final id = m['id'] as int;
          if (!_seenMessageIds.contains(id)) {
            _seenMessageIds.add(id);
            hasNew = true;
            // Trigger native system push notification
            NotificationService.showNotification(
              m['sender'] ?? 'IT Park',
              m['text'] ?? '',
            );
          }
        }
        if (hasNew) {
          await prefs.setStringList('seen_msg_ids', _seenMessageIds.map((id) => id.toString()).toList());
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/student-portal/dashboard/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
        _checkGamificationEvents();
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('student_token');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      } else {
        setState(() {
          _error = 'Ma\'lumotlarni yuklab bo\'lmadi: Status ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Tarmoq xatosi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkGamificationEvents() async {
    final student = _data?['student'] ?? {};
    final cardsState = student['cardsState'] ?? {};
    final stars = student['stars'] ?? 0;
    final int studentId = student['id'] ?? 0;

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check milestone 100 stars
    if (stars >= 100) {
      final key = 'milestone_100_celebrated_$studentId';
      final hasCelebrated = prefs.getBool(key) ?? false;
      if (!hasCelebrated) {
        await prefs.setBool(key, true);
        _showMilestoneCelebrationDialog(stars);
        return; // Prioritize milestone celebration over absences
      }
    }

    // 2. Check warning cards
    final yellowCount = cardsState['yellow_count'] ?? 0;
    final showRed = cardsState['show_red'] ?? false;
    final String currentWarningState = "${cardsState['show_yellow']}_${yellowCount}_$showRed";

    if (currentWarningState != _lastWarningState) {
      if (showRed) {
        _lastWarningState = currentWarningState;
        _showRedCardOverlay();
      } else if (cardsState['show_yellow'] == true) {
        _lastWarningState = currentWarningState;
        _showYellowCardOverlay(yellowCount);
      }
    }
  }

  void _showYellowCardOverlay(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = AppTheme.cardBg(ctx);
        final textColor = AppTheme.textPrimary(ctx);
        final textSecColor = AppTheme.textSecondary(ctx);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 20, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OGOHLANTIRISH!',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2),
                ),
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.asset('assets/yellow_card.png', height: 180),
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(1, 2)),
                          ],
                        ),
                        child: Text(
                          '${count}x',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF131C2E)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Siz $count kun sababsiz dars qoldirdingiz!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Iltimos, darslarni o\'z vaqtida qoldirmasdan keling. Yana dars qoldirsangiz, yulduzlaringiz ayrib tashlanadi va qizil kartochka beriladi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecColor, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BounceButton(
                    onTap: () => Navigator.pop(ctx),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: null, // let BounceButton handle tap
                      child: const Text(
                        'Tushundim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF131C2E)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRedCardOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardBg = AppTheme.cardBg(ctx);
        final textColor = AppTheme.textPrimary(ctx);
        final textSecColor = AppTheme.textSecondary(ctx);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.redAccent.withOpacity(0.15), blurRadius: 20, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QIZIL KARTOCHKA!',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2),
                ),
                const SizedBox(height: 20),
                Image.asset('assets/red_card.png', height: 180),
                const SizedBox(height: 20),
                Text(
                  'Ketma-ket 3 kun dars qoldirdingiz!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Qoida buzilganligi sababli: -15 yulduz!',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Darslarni sababsiz qoldirishda davom etsangiz, har bir kun uchun qo\'shimcha -3 yulduz jarima qo\'llaniladi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecColor, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BounceButton(
                    onTap: () => Navigator.pop(ctx),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: null, // let BounceButton handle tap
                      child: const Text(
                        'Tushundim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMilestoneCelebrationDialog(int stars) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final cardBg = AppTheme.cardBg(ctx);
        final textColor = AppTheme.textPrimary(ctx);
        final textSecColor = AppTheme.textSecondary(ctx);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 25, spreadRadius: 6),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TABRIKLAYMIZ!',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Image.asset('assets/star.png', height: 130),
                const SizedBox(height: 20),
                Text(
                  'Siz $stars ta yulduz yig\'dingiz!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ajoyib natija! IT Park darslarida faol bo\'lganingiz uchun rahmat. O\'qishda va yulduzlar yig\'ishda davom eting! 🏆',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecColor, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BounceButton(
                    onTap: () => Navigator.pop(ctx),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: null, // let BounceButton handle tap
                      child: const Text(
                        'Ura! Davom etamiz',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF131C2E)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDragging = false;
  double _dragX = 0.0;
  Timer? _tooltipTimer;
  bool _showTooltip = false;
  String _activeLabel = 'Bosh sahifa';
  final List<String> _studentLabels = ['Bosh sahifa', 'Davomat', 'To\'lovlar', 'Guruh Chat', 'Xabarlar'];

  void _handleDragUpdate(double localX, double tabWidth, int numTabs) {
    // Calculate the index based on drag X position
    int index = ((localX - 8) / tabWidth).round().clamp(0, numTabs - 1);
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _activeLabel = _studentLabels[index];
        _showTooltip = true;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _triggerTooltip(String label) {
    _tooltipTimer?.cancel();
    setState(() {
      _activeLabel = label;
      _showTooltip = true;
    });
    if (!_isDragging) {
      _tooltipTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _showTooltip = false;
          });
        }
      });
    }
  }



  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_token');
    await prefs.remove('is_default_password');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int screensLength) {
    final isSelected = (_currentIndex >= screensLength ? 0 : _currentIndex) == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.accentColor;
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _triggerTooltip(_studentLabels[index]);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isSelected ? activeColor : (isDark ? Colors.white38 : Colors.black45),
            size: 26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B050)),
                  child: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final student = _data?['student'] ?? {};
    final groups = _data?['groups'] ?? [];
    final payments = _data?['payments'] ?? [];
    final attendance = _data?['attendance'] ?? [];

    final List<Widget> screens = [
      DashboardTab(student: student, groups: groups, payments: payments, attendance: attendance, onRefresh: _fetchData),
      AttendanceTab(attendance: attendance, onRefresh: _fetchData),
      PaymentsTab(payments: payments, onRefresh: _fetchData),
      StudentGroupChatTab(token: widget.token, groups: groups),
      StudentChatTab(token: widget.token),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'IT PARK',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
            onPressed: _showStudentNotificationsModal,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Sozlamalar'),
                    ),
                    body: SettingsTab(token: widget.token, student: student, onLogout: _logout),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.accentColor),
            onPressed: _fetchData,
          )
        ],
        elevation: 6,
        shadowColor: AppTheme.accentColor.withOpacity(0.12),
        backgroundColor: AppTheme.cardBg(context).withOpacity(0.92),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex >= screens.length ? 0 : _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedOpacity(
            opacity: (_isDragging || _showTooltip) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                _activeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth - 32;
              final int numTabs = 5;
              final double tabWidth = (totalWidth - 16) / numTabs;

              return GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragX = details.localPosition.dx;
                  });
                  _handleDragUpdate(_dragX, tabWidth, numTabs);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _dragX = details.localPosition.dx;
                  });
                  _handleDragUpdate(_dragX, tabWidth, numTabs);
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                  });
                  _triggerTooltip(_activeLabel);
                },
                onPanCancel: () {
                  setState(() {
                    _isDragging = false;
                  });
                  _triggerTooltip(_activeLabel);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.fromLTRB(16, 0, 16, _isDragging ? 32 : 24),
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
                            duration: _isDragging ? const Duration(milliseconds: 16) : const Duration(milliseconds: 250),
                            curve: _isDragging ? Curves.linear : Curves.easeOutBack,
                            left: _isDragging 
                                ? (_dragX - tabWidth / 2).clamp(8.0, totalWidth - tabWidth - 8.0)
                                : (((_currentIndex >= numTabs ? 0 : _currentIndex) * tabWidth) + 8),
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
                              Expanded(child: _buildNavItem(0, Icons.dashboard_rounded, 'Bosh sahifa', screens.length)),
                              Expanded(child: _buildNavItem(1, Icons.calendar_today_rounded, 'Davomat', screens.length)),
                              Expanded(child: _buildNavItem(2, Icons.account_balance_wallet_rounded, 'To\'lovlar', screens.length)),
                              Expanded(child: _buildNavItem(3, Icons.group_rounded, 'Guruh Chat', screens.length)),
                              Expanded(child: _buildNavItem(4, Icons.forum_rounded, 'Xabarlar', screens.length)),
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
        ],
      ),
    );
  }

  Future<void> _showStudentNotificationsModal() async {
    await NotificationService.checkAndRequestPermissions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return FutureBuilder<http.Response>(
            future: ApiService.getStudentMessages(widget.token),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00B050))),
                );
              }
              if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                return SizedBox(
                  height: 300,
                  child: Center(
                    child: Text(
                      'Bildirishnomalarni yuklashda xatolik',
                      style: TextStyle(color: AppTheme.textSecondary(ctx)),
                    ),
                  ),
                );
              }
              
              final List<dynamic> messages = jsonDecode(snapshot.data!.body);
              final textColor = AppTheme.textPrimary(ctx);
              final textSecColor = AppTheme.textSecondary(ctx);
              final cardBgColor = AppTheme.isDark(ctx) ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9);

              return Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border(ctx), borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bildirishnomalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              Text('O\'qituvchilar tomonidan yuborilgan xabarlar', style: TextStyle(color: textSecColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(color: AppTheme.border(ctx), height: 24),
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Text('Sizga xabarlar yo\'q', style: TextStyle(color: textSecColor)),
                            )
                          : ListView.builder(
                              itemCount: messages.length,
                              itemBuilder: (ctx, i) {
                                final m = messages[i];
                                final createdTime = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal();
                                final dateStr = createdTime != null
                                    ? "${createdTime.day.toString().padLeft(2, '0')}.${createdTime.month.toString().padLeft(2, '0')}.${createdTime.year} ${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}"
                                    : '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.border(ctx)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            m['sender'] ?? 'IT Park',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        m['text'] ?? '',
                                        style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 13.5, height: 1.4),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        dateStr,
                                        style: TextStyle(color: textSecColor.withOpacity(0.5), fontSize: 11),
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
          );
        },
      ),
    );
  }
}

// ---- TAB 3.5: STUDENT CHAT PORTAL ----
class StudentChatTab extends StatefulWidget {
  final String token;
  const StudentChatTab({Key? key, required this.token}) : super(key: key);

  @override
  _StudentChatTabState createState() => _StudentChatTabState();
}

class _StudentChatTabState extends State<StudentChatTab> {
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
    _loadInitialData();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchMessages(isInitial: true);
    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom(force: true);
    }

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchMessages();
    });
  }

  Future<void> _fetchMessages({bool isInitial = false}) async {
    try {
      final res = await ApiService.getStudentMessages(widget.token);
      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body);
        
        final sorted = List.from(raw);
        sorted.sort((a, b) {
          final idA = a['id'] ?? 0;
          final idB = b['id'] ?? 0;
          return idA.compareTo(idB);
        });

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(sorted);
          });

          if (isInitial || _lastScrollMessageCount == null || _messages.length > _lastScrollMessageCount!) {
            _scrollToBottom();
            _lastScrollMessageCount = _messages.length;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching student messages: $e');
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (force) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        } else {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _msgCtrl.clear();
    });

    try {
      final res = await ApiService.sendStudentMessage(widget.token, text);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchMessages();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
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
                                'Xabarlar yo\'q.\nYozishishni boshlash uchun xabar yuboring!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, idx) {
                            final m = _messages[idx];
                            final isMe = m['isFromStudent'] == true;
                            final senderName = m['sender'] ?? 'IT Park';
                            final initials = _getInitials(senderName);
                            final time = _formatTime(m['createdAt'] ?? m['created_at']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    _getUserAvatar(m['avatar'], initials),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                                            child: Text(
                                              senderName,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                                    _getUserAvatar(null, initials, isMe: true),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
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
                          controller: _msgCtrl,
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
              ],
            ),
    );
  }
}

// ---- TAB 3.6: STUDENT GROUP CHAT ----
class StudentGroupChatTab extends StatelessWidget {
  final String token;
  final List<dynamic> groups;

  const StudentGroupChatTab({Key? key, required this.token, required this.groups}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (groups.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Siz faol guruhlarda emassiz', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: groups.length,
        itemBuilder: (ctx, i) {
          final g = groups[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF131C2E) : Colors.white,
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B050).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF00B050)),
              ),
              title: Text(
                g['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                g['schedule'] ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00B050)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupChatDetailScreen(
                      token: token,
                      groupId: g['id'],
                      groupName: g['name'] ?? 'Guruh chat',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class GroupChatDetailScreen extends StatefulWidget {
  final String token;
  final int groupId;
  final String groupName;

  const GroupChatDetailScreen({
    Key? key,
    required this.token,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _GroupChatDetailScreenState createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
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
      final res = await ApiService.getGroupMessages(widget.token, widget.groupId);
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
      final res = await ApiService.sendGroupMessageWithFile(
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
      debugPrint('Error sending group message: $e');
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

// ---- TAB 1: DASHBOARD ----
class DashboardTab extends StatelessWidget {
  final Map<String, dynamic> student;
  final List<dynamic> groups;
  final List<dynamic> payments;
  final List<dynamic> attendance;
  final Future<void> Function() onRefresh;

  const DashboardTab({
    Key? key,
    required this.student,
    required this.groups,
    required this.payments,
    required this.attendance,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);

    // Calculate total paid
    double totalPaid = 0.0;
    for (var p in payments) {
      totalPaid += (p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount'].toString()) ?? 0.0;
    }

    // Attendance stats
    int totalKeldi = attendance.where((a) => a['status'] == 'keldi').length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Student Profile Card in 3D
          PremiumFadeIn(
            duration: const Duration(milliseconds: 300),
            child: ThreeDContainer(
              height: 180,
              gradientColors: [
                isDark ? const Color(0xFF161F30) : Colors.white,
                const Color(0xFF00B050).withOpacity(0.08)
              ],
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF00B050),
                        child: Text(
                          (student['firstName'] ?? 'O').substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}',
                                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1F2C42) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset('assets/star.png', width: 20, height: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${student['stars'] ?? 0}',
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${student['studentId'] ?? ''}',
                              style: const TextStyle(color: Color(0xFF00B050), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  Divider(height: 32, color: AppTheme.border(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Telefon', style: TextStyle(color: textSecColor, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(student['phone'] ?? '-', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Guruhlar soni', style: TextStyle(color: textSecColor, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${groups.length} ta', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          
          // Stats Row
          PremiumFadeIn(
            duration: const Duration(milliseconds: 400),
            child: Row(
              children: [
                Expanded(
                  child: ThreeDContainer(
                    height: 110,
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Color(0xFF00B050), size: 24),
                        const Spacer(),
                        Text('Jami to\'langan', style: TextStyle(color: textSecColor, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text('${totalPaid.toStringAsFixed(0)} UZS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ThreeDContainer(
                    height: 110,
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 24),
                        const Spacer(),
                        Text('Darslardagi ishtirok', style: TextStyle(color: textSecColor, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text('$totalKeldi / ${attendance.length}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Enrolled Groups Title
          Text(
            'Mening guruhlarim',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),

          if (groups.isEmpty)
            PremiumFadeIn(
              duration: const Duration(milliseconds: 500),
              child: Card(
                color: AppTheme.cardBg(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Hozirda hech qaysi guruhga a\'zo emassiz.', style: TextStyle(color: textSecColor)),
                ),
              ),
            )
          else
            ...List.generate(groups.length, (index) {
              final g = groups[index];
              return PremiumFadeIn(
                duration: Duration(milliseconds: 300 + (index * 80)),
                child: ThreeDContainer(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.group, color: Color(0xFF00B050)),
                    title: Text(g['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text('Jadval: ${g['schedule'] ?? ''}', style: TextStyle(color: textSecColor)),
                    trailing: Text(
                      '${g['price']} UZS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---- TAB 2: ATTENDANCE ----
class AttendanceTab extends StatelessWidget {
  final List<dynamic> attendance;
  final Future<void> Function() onRefresh;

  const AttendanceTab({
    Key? key,
    required this.attendance,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: attendance.isEmpty
          ? Center(child: Text('Davomat ma\'lumotlari mavjud emas.', style: TextStyle(color: textSecColor)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: attendance.length,
              itemBuilder: (context, index) {
                final record = attendance[index];
                final status = record['status']?.toString().toLowerCase() ?? '';
                
                Color statusColor;
                String statusLabel;
                switch (status) {
                  case 'keldi':
                    statusColor = const Color(0xFF00B050);
                    statusLabel = 'Keldi';
                    break;
                  case 'kelmadi':
                    statusColor = Colors.redAccent;
                    statusLabel = 'Kelmadi';
                    break;
                  case 'kechikdi':
                    statusColor = Colors.orangeAccent;
                    statusLabel = 'Kechikdi';
                    break;
                  case 'sababli':
                    statusColor = Colors.blueAccent;
                    statusLabel = 'Sababli';
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusLabel = status;
                }

                return PremiumFadeIn(
                  duration: Duration(milliseconds: 300 + (index * 60)),
                  child: ThreeDContainer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['groupName'] ?? '',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record['date'] ?? '',
                              style: TextStyle(color: textSecColor, fontSize: 13),
                            ),
                            if (record['note'] != null && record['note'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Izoh: ${record['note']}', style: TextStyle(fontSize: 12, color: textSecColor.withOpacity(0.8), fontStyle: FontStyle.italic)),
                            ]
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---- TAB 3: PAYMENTS ----
class PaymentsTab extends StatelessWidget {
  final List<dynamic> payments;
  final Future<void> Function() onRefresh;

  const PaymentsTab({
    Key? key,
    required this.payments,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: payments.isEmpty
          ? Center(child: Text('To\'lov ma\'lumotlari mavjud emas.', style: TextStyle(color: textSecColor)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                final amount = (payment['amount'] is num) ? (payment['amount'] as num).toDouble() : double.tryParse(payment['amount'].toString()) ?? 0.0;
                final discount = payment['discount'] ?? 0;

                return PremiumFadeIn(
                  duration: Duration(milliseconds: 300 + (index * 60)),
                  child: ThreeDContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF00B050).withOpacity(0.15),
                        child: const Icon(Icons.attach_money, color: Color(0xFF00B050)),
                      ),
                      title: Text(
                        payment['groupName'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Oy: ${payment['month'] ?? ''}', style: TextStyle(color: textSecColor)),
                          if (discount > 0) ...[
                            const SizedBox(height: 2),
                            Text('Chegirma: $discount UZS', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${amount.toStringAsFixed(0)} UZS',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00B050)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment['createdAt']?.toString().split('T')[0] ?? '',
                            style: TextStyle(color: textSecColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---- TAB 4: SETTINGS ----
class SettingsTab extends StatelessWidget {
  final String token;
  final Map<String, dynamic> student;
  final VoidCallback onLogout;

  const SettingsTab({
    Key? key,
    required this.token,
    required this.student,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.textPrimary(context);
    final textSecColor = AppTheme.textSecondary(context);

    return PremiumFadeIn(
      duration: const Duration(milliseconds: 300),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Info Header
          ThreeDContainer(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF00B050), size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IT Park Surkhandaryo App',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O\'quvchilar va ota-onalar portali\nVersiya 1.0.0',
                        style: TextStyle(fontSize: 12, color: textSecColor),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Actions Card
          ThreeDContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ITParkApp.themeNotifier,
                  builder: (_, ThemeMode currentMode, __) {
                    final isLight = currentMode == ThemeMode.light;
                    return SwitchListTile(
                      activeColor: const Color(0xFF00B050),
                      title: Text(
                        'Kunduzgi rejim (Light mode)',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                      ),
                      value: isLight,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_light_theme', val);
                        ITParkApp.themeNotifier.value = val ? ThemeMode.light : ThemeMode.dark;
                      },
                      secondary: Icon(
                        isLight ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                        color: const Color(0xFF00B050),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: AppTheme.border(context)),
                BounceButton(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChangePasswordScreen(
                          token: token,
                          isForced: false,
                          onPasswordChanged: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: Icon(Icons.lock_open, color: AppTheme.accentColor),
                    title: Text('Parolni o\'zgartirish', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, color: textSecColor),
                  ),
                ),
                Divider(height: 1, color: AppTheme.border(context)),
                BounceButton(
                  onTap: onLogout,
                  child: const ListTile(
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: Text('Tizimdan chiqish', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  ),
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
