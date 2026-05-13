// ignore_for_file: avoid_print, unused_field
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/member/renew/screens/renew_member.dart';

class RenewScreen2 extends StatefulWidget {
  final String memberId;
  final RenewRegistrationData data;
  final VoidCallback onPrevious;
  final VoidCallback onSubmit;

  const RenewScreen2({
    super.key,
    required this.data,
    required this.onSubmit,
    required this.memberId,
    required this.onPrevious,
  });

  @override
  State<RenewScreen2> createState() => _RenewScreen2State();
}

class _RenewScreen2State extends State<RenewScreen2> {
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
    final processedVehicles = widget.data.vehicles.map((vehicle) {
      if (vehicle.containsKey('vehicle_id') && vehicle['vehicle_id'] != null) {
        return {
          'id': int.parse(vehicle['vehicle_id']!),
          'vehicle_type': vehicle['vehicle_type'],
          'vehicle_number': vehicle['vehicle_number'],
          'total_amount': vehicle['total_amount'],
        };
      } else {
        return {
          'vehicle_type': vehicle['vehicle_type'],
          'vehicle_number': vehicle['vehicle_number'],
          'total_amount': vehicle['total_amount'],
        };
      }
    }).toList();
    final requestData = {
      'vehicles': processedVehicles,
      'start_date': widget.data.startDate,
      'end_date': widget.data.endDate,
      'payment_method': widget.data.paymentMethod,
      'received_by': widget.data.recievedBy,
    };
    print('request data : $requestData');
    try {
      final token = await SecureStorage.getAccessToken();
      final response = await http.patch(
        Uri.parse(
          '${ApiEndpoints.baseUrl}membership/members/${widget.memberId}/renew/',
        ),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",
        },
        body: json.encode(requestData),
      );
      print(response.statusCode);
      print(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Renewal successful!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSubmit();
        }
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                        validator: (value) => value == null
                            ? 'Please select payment method'
                            : null,
                      ),

                      const SizedBox(height: 20),
                      _buildLabel('Received By'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _recievedByController,
                        decoration: InputDecoration(
                          hintText: 'Enter receiver name',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D1D1),
                            ),
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
          ],
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
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFFD1D1D1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
