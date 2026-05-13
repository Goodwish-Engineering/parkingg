import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';

// Model classes
class Member {
  final int id;
  final String name;
  final String phoneNumber;
  final String membershipType;
  final String shopNumber;
  final String customerVat;
  final String createdAt;
  final String receivedBy;
  final List<Vehicle> vehicles;
  final String paymentMethod;
  final String startDate;
  final String endDate;

  Member({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.membershipType,
    required this.shopNumber,
    required this.customerVat,
    required this.createdAt,
    required this.receivedBy,
    required this.vehicles,
    required this.paymentMethod,
    required this.startDate,
    required this.endDate,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as int,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      membershipType: json['membership_type'] as String,
      shopNumber: json['shop_number'] as String,
      customerVat: json['customer_vat'] as String,
      createdAt: json['created_at'] as String,
      receivedBy: json['received_by'] as String,
      vehicles: (json['vehicles'] as List)
          .map((v) => Vehicle.fromJson(v))
          .toList(),
      paymentMethod: json['payment_method'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );
  }
}

class Vehicle {
  final int id;
  final String vehicleNumber;
  final String vehicleType;
  final double totalAmount;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.totalAmount,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
    );
  }
}

class MemberService {
  static Future<Member> fetchMemberDetails(String memberId) async {
    final token = await SecureStorage.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiEndpoints.baseUrl}membership/members/$memberId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return Member.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load member details');
    }
  }
}

class MemberDetailsScreen extends StatefulWidget {
  final String memberId;

  const MemberDetailsScreen({super.key, required this.memberId});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  late Future<Member> futureMember;

  @override
  void initState() {
    super.initState();
    futureMember = MemberService.fetchMemberDetails(widget.memberId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B8FB9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Member Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<Member>(
        future: futureMember,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data found'));
          }

          final member = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMemberInfoCard(member),
                  const SizedBox(height: 24),
                  _buildRegisteredVehicles(member.vehicles),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberInfoCard(Member member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Member Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC0C0C0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFDBDBDB)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.store, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                'Shop No: ${member.shopNumber}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          Text(
                            'VAT: ${member.customerVat}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildInfoRow('Name:', member.name),
                    _buildInfoRow('Contact No:', member.phoneNumber),
                    _buildInfoRow('Membership Type:', member.membershipType),
                    _buildInfoRow('Start Date:', member.startDate),
                    _buildInfoRow('Expiry Date:', member.endDate),
                    _buildInfoRow(
                      'Payment Method:',
                      member.paymentMethod,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredVehicles(List<Vehicle> vehicles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Registered Vehicles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        SizedBox(
          height: 115,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: vehicles.map((vehicle) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildVehicleCard(vehicle),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    final isFourWheeler = vehicle.vehicleType == 'FOUR_WHEELER';
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFC0C0C0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.06),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFBEB9D9), Color(0xFF13008C)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(6.94),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        isFourWheeler
                            ? Icons.directions_car
                            : Icons.two_wheeler,
                        size: 25,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isFourWheeler ? 'Four Wheeler' : 'Two Wheeler',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              vehicle.vehicleNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${vehicle.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF3F3F3F)),
            ),
          ],
        ),
      ),
    );
  }
}
