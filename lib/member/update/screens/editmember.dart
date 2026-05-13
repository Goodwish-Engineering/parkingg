// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/member/update/screens/screen1.dart';
import 'package:parking/member/update/screens/screen2.dart';
import 'package:parking/member/update/screens/screen3.dart';

class UpdateRegistraton extends StatefulWidget {
  final String memberId;
  const UpdateRegistraton({super.key, required this.memberId});

  @override
  State<UpdateRegistraton> createState() => _UpdateRegistratonState();
}

class _UpdateRegistratonState extends State<UpdateRegistraton> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final UpdateRegistrationData _registrationData = UpdateRegistrationData();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchupdate();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> fetchupdate() async {
    final token = await SecureStorage.getAccessToken();

    final response = await http.get(
      Uri.parse(
        '${ApiEndpoints.baseUrl}membership/members/${widget.memberId}/',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        _registrationData.name = data['name'];
        _registrationData.contactNo = data['phone_number'];
        _registrationData.membershipType = data['membership_type'];
        _registrationData.shopNo = data['shop_number'];
        _registrationData.vatRegistrationNo = data['customer_vat'];
        _registrationData.recievedBy = data['received_by'];
        _registrationData.paymentMethod = data['payment_method'];
        _registrationData.startDate = data['start_date'];
        _registrationData.endDate = data['end_date'];

        _registrationData.vehicles = List<Map<String, String>>.from(
          data['vehicles'].map(
            (v) => {
              'vehicle_id': v['id'].toString(),
              'vehicle_type': v['vehicle_type'].toString(),
              'vehicle_number': v['vehicle_number'].toString(),
              'total_amount': v['total_amount'].toString(),
            },
          ),
        );

        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Failed to load member');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF668DAF),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildPageContent(
                  Screen1(
                    data: _registrationData,
                    onNext: _nextPage,
                    onPrevious: _previousPage,
                    isFirstPage: true,
                  ),
                ),
                _buildPageContent(
                  Screen2(
                    data: _registrationData,
                    onNext: _nextPage,
                    onPrevious: _previousPage,
                  ),
                ),
                _buildPageContent(
                  Screen3(
                    memberId: widget.memberId,
                    data: _registrationData,
                    onPrevious: _previousPage,
                    onSubmit: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPageContent(Widget child) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Edit Membership',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          _buildProgressIndicator(),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(1, 'Member\nRegistration', _currentPage >= 0),
          _buildProgressLine(_currentPage >= 1),
          _buildStep(2, 'Vehicle &\nMembership', _currentPage >= 1),
          _buildProgressLine(_currentPage >= 2),
          _buildStep(3, 'Payment &\nValidity', _currentPage >= 2),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4CAF50) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF4CAF50) : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.2,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 30, left: 4, right: 4),
      color: isActive ? const Color(0xFF4CAF50) : Colors.white,
    );
  }
}

class UpdateRegistrationData {
  String? name;
  String? contactNo;
  String? vatRegistrationNo;
  String? shopNo;
  String? membershipType;
  List<Map<String, String>> vehicles = [];
  String? startDate;
  String? endDate;
  String? paymentMethod;
  String? totalAmount;
  String? recievedBy;
}
