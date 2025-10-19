import 'dart:convert';
import 'package:http/http.dart' as http;

class PhoneVerificationService {
  static final PhoneVerificationService instance = PhoneVerificationService._init();
  
  final String _baseUrl = 'https://staging.hourandmore.sa/api';
  
  PhoneVerificationService._init();

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      print('Sending OTP to phone: $phone');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/sendOtp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'phone': phone,
        }),
      );

      print('Send OTP Response Status: ${response.statusCode}');
      print('Send OTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'OTP sent successfully',
            'data': data,
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'OTP sent successfully',
            'data': response.body,
          };
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to send OTP',
            'error': errorData,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error (${response.statusCode}): ${response.reasonPhrase}',
            'error': response.body,
          };
        }
      }
    } catch (e) {
      print('Send OTP Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> confirmOtp({
    required String phone,
    required String code,
    required String userType,
  }) async {
    try {
      print('Confirming OTP for phone: $phone, code: $code, userType: $userType');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/confirmOtp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'phone': phone,
          'code': code,
          'user_type': userType,
        }),
      );

      print('Confirm OTP Response Status: ${response.statusCode}');
      print('Confirm OTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'OTP verified successfully',
            'data': data,
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'OTP verified successfully',
            'data': response.body,
          };
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to verify OTP',
            'error': errorData,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error (${response.statusCode}): ${response.reasonPhrase}',
            'error': response.body,
          };
        }
      }
    } catch (e) {
      print('Confirm OTP Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }
}
