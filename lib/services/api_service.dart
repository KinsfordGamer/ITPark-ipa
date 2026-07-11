import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String kBaseUrl = 'https://itparksurhondaryocrm.one/api';

class ApiService {
  static String? _adminToken;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adminToken = prefs.getString('admin_token');
  }

  static Future<void> saveAdminToken(String token, Map<String, dynamic> user) async {
    _adminToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', token);
    await prefs.setString('admin_user', jsonEncode(user));
  }

  static Future<void> clearAdminToken() async {
    _adminToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user');
  }

  static Future<String?> getAdminToken() async {
    if (_adminToken != null) return _adminToken;
    final prefs = await SharedPreferences.getInstance();
    _adminToken = prefs.getString('admin_token');
    return _adminToken;
  }

  static Future<Map<String, dynamic>?> getAdminUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('admin_user');
    if (str == null) return null;
    return jsonDecode(str);
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ---- AUTH ----
  static Future<http.Response> adminLogin(String phone, String password) {
    return http.post(
      Uri.parse('$kBaseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
  }

  // ---- DASHBOARD ----
  static Future<http.Response> getDashboardStats(String token) {
    return http.get(Uri.parse('$kBaseUrl/dashboard/stats/'), headers: _headers(token));
  }

  // ---- STUDENTS ----
  static Future<http.Response> getStudents(String token) {
    return http.get(Uri.parse('$kBaseUrl/students/?limit=1000'), headers: _headers(token));
  }

  static Future<http.Response> createStudent(String token, Map<String, dynamic> data) {
    return http.post(
      Uri.parse('$kBaseUrl/students/'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
  }

  static Future<http.Response> updateStudent(String token, int id, Map<String, dynamic> data) {
    return http.put(
      Uri.parse('$kBaseUrl/students/$id/'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
  }

  // ---- GROUPS ----
  static Future<http.Response> getGroups(String token) {
    return http.get(Uri.parse('$kBaseUrl/groups/?limit=1000'), headers: _headers(token));
  }

  static Future<http.Response> addStudentToGroup(String token, int groupId, int studentId, String joinedAt) {
    return http.post(
      Uri.parse('$kBaseUrl/groups/$groupId/add_student/'),
      headers: _headers(token),
      body: jsonEncode({'studentId': studentId, 'joinedAt': joinedAt}),
    );
  }

  // ---- PAYMENTS ----
  static Future<http.Response> getPayments(String token) {
    return http.get(Uri.parse('$kBaseUrl/payments/?limit=1000'), headers: _headers(token));
  }

  static Future<http.Response> createPayment(String token, Map<String, dynamic> data) {
    return http.post(
      Uri.parse('$kBaseUrl/payments/'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
  }

  static Future<http.Response> deletePayment(String token, int id) {
    return http.delete(Uri.parse('$kBaseUrl/payments/$id/'), headers: _headers(token));
  }

  // ---- ATTENDANCE ----
  static Future<http.Response> getAttendanceRecords(String token, {int? groupId, String? date}) {
    String url = '$kBaseUrl/attendance-records/?limit=1000';
    if (groupId != null) url += '&group=$groupId';
    if (date != null) url += '&date=$date';
    return http.get(Uri.parse(url), headers: _headers(token));
  }

  static Future<http.Response> bulkSaveAttendance(String token, List<Map<String, dynamic>> records) {
    return http.post(
      Uri.parse('$kBaseUrl/attendance/bulk-save/'),
      headers: _headers(token),
      body: jsonEncode({'records': records}),
    );
  }

  // ---- USERS ----
  static Future<http.Response> getUsers(String token) {
    return http.get(Uri.parse('$kBaseUrl/users/?limit=1000'), headers: _headers(token));
  }

  // ---- MESSAGES ----
  static Future<http.Response> sendMessage(String token, String text) {
    return http.post(
      Uri.parse('$kBaseUrl/messages/'),
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
  }

  static Future<http.Response> getMessages(String token) {
    return http.get(Uri.parse('$kBaseUrl/messages/?limit=1000'), headers: _headers(token));
  }

  static Future<http.Response> getStudentMessages(String token) {
    return http.get(Uri.parse('$kBaseUrl/student-portal/messages/'), headers: _headers(token));
  }

  static Future<http.Response> sendStudentMessage(String token, String text) {
    return http.post(
      Uri.parse('$kBaseUrl/student-portal/messages/'),
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
  }

  // ---- GROUP CHAT ENDPOINTS ----
  static Future<http.Response> getGroupMessages(String token, int groupId) {
    return http.get(Uri.parse('$kBaseUrl/student-portal/groups/$groupId/messages/'), headers: _headers(token));
  }

  static Future<http.StreamedResponse> sendGroupMessageWithFile(String token, int groupId, String text, String? filePath, String? fileName) async {
    final uri = Uri.parse('$kBaseUrl/student-portal/groups/$groupId/messages/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });
    request.fields['text'] = text;
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    }
    return request.send();
  }

  static Future<http.Response> getStaffGroupMessages(String token, int groupId) {
    return http.get(Uri.parse('$kBaseUrl/groups/$groupId/messages/'), headers: _headers(token));
  }

  static Future<http.StreamedResponse> sendStaffGroupMessageWithFile(String token, int groupId, String text, String? filePath, String? fileName) async {
    final uri = Uri.parse('$kBaseUrl/groups/$groupId/messages/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });
    request.fields['text'] = text;
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    }
    return request.send();
  }

  static bool handleAuthError(BuildContext context, http.Response response) {
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.body.contains("token_not_valid") ||
        response.body.contains("Token is expired")) {
      clearAdminToken().then((_) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('student_token');
          prefs.remove('is_default_password');
          prefs.remove('admin_token');
          prefs.remove('admin_user');
          
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔴 Seans muddati tugadi. Iltimos, tizimga qaytadan kiring.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
          );
        });
      });
      return true;
    }
    return false;
  }
}
