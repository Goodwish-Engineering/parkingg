// ignore_for_file: avoid_print, unused_field
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/drawer/add_member.dart';
import 'package:parking/home/screens/root_app.dart';

class PaymentValidityScreen extends StatefulWidget {
  final RegistrationData data;
  final VoidCallback onPrevious;

  const PaymentValidityScreen({
    super.key,
    required this.data,
    required this.onPrevious,
  });

  @override
  State<PaymentValidityScreen> createState() => _PaymentValidityScreenState();
}

class _PaymentValidityScreenState extends State<PaymentValidityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recievedByController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _recievedByController = TextEditingController(text: widget.data.recievedBy);
  }

  @override
  void dispose() {
    _recievedByController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    widget.data.recievedBy = _recievedByController.text;

    final requestData = {
      'name': widget.data.name,
      'phone_number': widget.data.contactNo,
      'customer_vat': widget.data.vatRegistrationNo,
      'shop_number': widget.data.shopNo,
      'membership_type': widget.data.membershipType,
      'vehicles': widget.data.vehicles,
      'start_date': widget.data.startDate,
      'end_date': widget.data.endDate,
      'payment_method': widget.data.paymentMethod,
      'received_by': widget.data.recievedBy,
    };
    print('request data : $requestData');
    try {
      final token = await SecureStorage.getAccessToken();
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}membership/members/register-member/'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",
        },
        body: json.encode(requestData),
      );
      print(response.body);
      print(response.statusCode);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to register member'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register member'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 20),
                _buildLabel('Payment Method'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: widget.data.paymentMethod,
                  decoration: _dropdownDecoration('Select Payment Mode'),
                  items: ['CASH', 'ONLINE']
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => widget.data.paymentMethod = value),
                  validator: (value) =>
                      value == null ? 'Please select payment method' : null,
                ),

                const SizedBox(height: 20),
                _buildLabel('Recieved By'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recievedByController,
                  decoration: InputDecoration(
                    hintText: 'Enter receiver name',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFD1D1D1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter receiver name'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: widget.onPrevious,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 14),
              const SizedBox(width: 8),
              const Text(
                'Previous',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004DE8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Add Member',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFD1D1D1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
