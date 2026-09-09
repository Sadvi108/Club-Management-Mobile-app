import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});
  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  static const _getEndpoints = <String>[
    '/Account/GetBranchesByClubCode/{clubCode}',
    '/ClassBooking/BookingCountByPackageSession/{packageTypeId}/{packageId}/{studentId}/{month}/{year}',
    '/ClassBooking/BookingsByInstructor/{instructorId}/{month}/{year}',
    '/ClassBooking/GetBookings',
    '/ClassBooking/NextBookings',
    '/ClassBooking/PackageInfo/{studentId}',
    '/ClassBooking/SessionOrPackages/{typeId}',
    '/ClassBooking/TrainingTimeWithDateAndInstructor/{month}/{year}/{tCenterId}/{instructorId}',
    '/Listing/DropdownListByType/{reportTypeId}',
    '/Listing/GetBranchesByClubCode/{clubCode}',
    '/Listing/Instructors',
    '/Listing/InvoceTypes',
    '/Listing/MySiblings',
    '/Listing/StoreVersion/{platform}',
    '/Listing/StudentCenters',
    '/Listing/StudentListByTcId/{TCenterId}',
    '/Listing/TrainingCenters',
    '/Listing/TrainingCentersByScId/{SCenterId}',
    '/Listing/TrainingTimeByTcId/{TCenterId}',
    '/Outstanding/CollectionCount',
    '/Outstanding/CollectionCountList/{typeId}',
    '/Outstanding/UpdateCollectionCount/{typeId}',
    '/Payment/Completed/{status}',
    '/Payment/Finalizing',
    '/Payment/Initiate',
    '/Profile/MyClubStats',
    '/Profile/MyInfo',
    '/Profile/MyNotifications',
    '/Profile/MyUnreadNotificationCount',
    '/Profile/MyUnreadNotifications',
    '/Profile/NotificationDetails/{groupid}',
    '/Profile/StudentAddtnlInfo',
    '/Profile/UpdateNotification2Read',
    '/Reports/ExamCenters',
    '/Reports/HomePageStats',
    '/Reports/StudentCenters',
    '/Reports/TrainingCenters',
    '/Utilities/QRCode/{width}/{height}/{content}',
    '/Utilities/ReceiptAsPDF/{clubId}/{paymentId}/{invoiceId}',
    '/Utilities/StudentQRCode/{clubId}/{branchId}/{studentIds}',
    '/Utilities/TrainingCenterQRCode/{clubId}/{tcid}',
  ];

  String _result = 'Press a button to test API';
  bool _loading = false;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clubCodeController = TextEditingController();
  final _branchIdController = TextEditingController();
  int _userType = 3;
  int _accessMethod = 0;
  final _deviceTypeController = TextEditingController(text: 'mobile');

  final _tokenController = TextEditingController();

  Future<void> _login({required bool thenTestMyInfo}) async {
    setState(() {
      _loading = true;
      _result = 'Logging in...';
    });
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password are required');
      }

      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'userType': _userType,
        'accessMethod': _accessMethod,
        'deviceType': _deviceTypeController.text.trim().isEmpty
            ? null
            : _deviceTypeController.text.trim(),
      };

      final clubCode = _clubCodeController.text.trim();
      if (clubCode.isNotEmpty) body['clubCode'] = clubCode;

      final branchIdText = _branchIdController.text.trim();
      if (branchIdText.isNotEmpty) {
        final parsed = int.tryParse(branchIdText);
        if (parsed == null) throw Exception('branchId must be a number');
        body['branchId'] = parsed;
      }

      final resp = await ApiService.post('/Account/Authenticate', body);
      String? token;
      if (resp is Map) {
        final data = resp['data'];
        if (data is Map) token = data['accessToken']?.toString();
      }
      if (token == null || token.trim().isEmpty) {
        throw Exception('No accessToken found in /Account/Authenticate response');
      }

      ApiService.setToken(token);
      setState(() {
        _tokenController.text = token!;
        _result = '✅ Login success. Token set (hidden).';
      });

      if (thenTestMyInfo) {
        await _testGet('/Profile/MyInfo');
      }
    } catch (e) {
      final msg = e.toString();
      final isCorsLike = msg.contains('XMLHttpRequest error') ||
          msg.contains('CORS') ||
          msg.contains('Failed to fetch');
      setState(() {
        _result = kIsWeb && isCorsLike
            ? '❌ ERROR (CORS blocked)\n\nThe browser blocked this request.\n\nFix:\n- Run the app on Windows/Android/iOS (recommended), OR\n- Launch Chrome with disabled web security for local testing.\n\nOriginal error:\n$msg'
            : '❌ ERROR\n\n$msg';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _testGet(String endpoint) async {
    if (endpoint.contains('{') && endpoint.contains('}')) {
      setState(() {
        _result =
            '❌ ERROR\n\nThis endpoint has placeholders.\n\nReplace values like {clubCode} before testing:\n$endpoint';
      });
      return;
    }
    setState(() {
      _loading = true;
      _result = 'Calling $endpoint ...';
    });
    try {
      final data = await ApiService.get(endpoint);
      setState(() {
        _result = '✅ SUCCESS\n\n${data.toString()}';
      });
    } catch (e) {
      final msg = e.toString();
      final isCorsLike = msg.contains('XMLHttpRequest error') ||
          msg.contains('CORS') ||
          msg.contains('Failed to fetch');
      setState(() {
        _result = kIsWeb && isCorsLike
            ? '❌ ERROR (CORS blocked)\n\nThe browser blocked this request.\n\nFix:\n- Run the app on Windows/Android/iOS (recommended), OR\n- Launch Chrome with disabled web security for local testing.\n\nOriginal error:\n$msg'
            : '❌ ERROR\n\n$msg';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Test - DB Check')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _userType,
                    decoration: const InputDecoration(
                      labelText: 'User Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _userType = v ?? 3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _accessMethod,
                    decoration: const InputDecoration(
                      labelText: 'Access Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0')),
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _accessMethod = v ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clubCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Club Code (optional)',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _branchIdController,
                    decoration: const InputDecoration(
                      labelText: 'Branch Id (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceTypeController,
              decoration: const InputDecoration(
                labelText: 'Device Type (optional)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _login(thenTestMyInfo: true),
                    child: const Text('Login + Test /Profile/MyInfo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _login(thenTestMyInfo: false),
                    child: const Text('Login Only'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Bearer Token (optional)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final token = _tokenController.text.trim();
                      if (token.isNotEmpty) ApiService.setToken(token);
                      setState(() {
                        _result = token.isEmpty
                            ? 'Token cleared (none set)'
                            : 'Token set (hidden)';
                      });
                    },
                    child: const Text('Set Token'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _testGet('/Profile/MyInfo'),
                    child: const Text('Quick Test: /Profile/MyInfo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _getEndpoints.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final endpoint = _getEndpoints[index];
                  return ElevatedButton(
                    onPressed: _loading ? null : () => _testGet(endpoint),
                    child: Text(
                      endpoint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _result,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _clubCodeController.dispose();
    _branchIdController.dispose();
    _deviceTypeController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
