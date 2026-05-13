// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/member/models/vehciletype.dart';
import 'package:parking/member/update/screens/editmember.dart';

class Screen2 extends StatefulWidget {
  final UpdateRegistrationData data;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const Screen2({
    super.key,
    required this.data,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNoController = TextEditingController();
  String? _membershipType;
  List<VehicleType> vehicleTypes = [];
  bool isLoadingVehicleTypes = true;

  @override
  void initState() {
    super.initState();
    fetchvehicletype();
    _membershipType = widget.data.membershipType;
  }

  @override
  void dispose() {
    _vehicleNoController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      widget.data.membershipType = _membershipType;
      widget.onNext();
    }
  }

  Future<void> fetchvehicletype() async {
    final token = await SecureStorage.getAccessToken();

    final response = await http.get(
      Uri.parse(
        '${ApiEndpoints.baseUrl}parkinginfo/parking-rates/active-rates/',
      ),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      setState(() {
        vehicleTypes = data.map((e) => VehicleType.fromJson(e)).toList();
        isLoadingVehicleTypes = false;
      });
    } else {
      isLoadingVehicleTypes = false;
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
                  'Vehicle & Membership',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildLabel('Membership Type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _membershipType,
                  decoration: _dropdownDecoration('Select Membership Type'),
                  items: ['monthly inhouse', 'monthly outhouse']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _membershipType = value),
                  validator: (value) =>
                      value == null ? 'Please select membership type' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _buildLabel('Start Date'),
                          const SizedBox(height: 8),

                          _buildNepaliDatePicker(
                            selectedDate: widget.data.startDate,
                            onDateSelected: (nepaliString) => setState(
                              () => widget.data.startDate = nepaliString,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _buildLabel('End Date'),
                          const SizedBox(height: 8),
                          _buildNepaliDatePicker(
                            selectedDate: widget.data.endDate,
                            onDateSelected: (nepaliString) => setState(
                              () => widget.data.endDate = nepaliString,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openAddVehicleBottomSheet,
                  icon: const Icon(
                    Icons.add,
                    size: 20,
                    color: Color(0xFF0044FF),
                  ),
                  label: const Text(
                    'Add Vehicle',
                    style: TextStyle(color: Color(0xFF0044FF)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F6FF),
                    foregroundColor: const Color(0xFF0044FF),
                    side: const BorderSide(
                      color: Color(0xFFBCCFFF),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.data.vehicles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Saved Vehicles (${widget.data.vehicles.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSavedVehicles(),
                ],
                const SizedBox(height: 20),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNepaliDatePicker({
    required String? selectedDate,
    required Function(String) onDateSelected,
    String? firstDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final NepaliDateTime? pickedNepaliDate =
                await showAdaptiveDatePicker(
                  context: context,
                  initialDate: selectedDate != null
                      ? _parseNepaliDate(selectedDate)
                      : NepaliDateTime.now(),
                  firstDate: firstDate != null
                      ? _parseNepaliDate(firstDate)
                      : NepaliDateTime(2070, 1, 1),
                  lastDate: NepaliDateTime(2090, 12, 30),
                );

            if (pickedNepaliDate != null) {
              String nepaliDateString = NepaliDateFormat(
                "yyyy-MM-dd",
              ).format(pickedNepaliDate);
              onDateSelected(nepaliDateString);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1D1D1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedDate ?? 'Select Date',
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  NepaliDateTime _parseNepaliDate(String dateString) {
    final parts = dateString.split('-');
    return NepaliDateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Widget _buildSavedVehicles() {
    // Show loading indicator if vehicle types are still loading
    if (isLoadingVehicleTypes || vehicleTypes.isEmpty) {
      return Container(
        height: 115,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.data.vehicles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final vehicle = widget.data.vehicles[index];
          final vehicleTypeString = vehicle['vehicle_type'].toString();
          final vehicleTypeData = vehicleTypes.firstWhere(
            (vt) => vt.vehicleType == vehicleTypeString,
          );

          return Container(
            width: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFC0C0C0)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        widget.data.vehicles.removeAt(index);
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.remove,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: vehicleTypeData.icon.isNotEmpty
                                  ? Image.network(
                                      vehicleTypeData.icon,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.directions_car,
                                              color: Colors.grey,
                                            );
                                          },
                                    )
                                  : const Icon(
                                      Icons.directions_car,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vehicleTypeData.vehicleType.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          vehicle['vehicle_number']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddVehicleBottomSheet() {
    String? vehicleType;
    final vehicleNoController = TextEditingController();
    final amountController = TextEditingController();
    final sheetFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      backgroundColor: Color(0xFFF2F2F2),
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: sheetFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Vehicle Type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration('Select Vehicle Type'),
                    items: vehicleTypes.map((vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle.vehicleType,
                        child: Text(vehicle.vehicleType.replaceAll('_', ' ')),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Select vehicle type' : null,
                    onChanged: (value) => vehicleType = value,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Vehicle No'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: vehicleNoController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter vehicle number',
                      filled: true,
                      fillColor: const Color(0xFFF5FAFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFFD1D1D1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter vehicle number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Amount'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      filled: true,
                      fillColor: const Color(0xFFF5FAFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFFD1D1D1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Enter amount' : null,
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        child: ElevatedButton(
                          onPressed: () {
                            if (sheetFormKey.currentState!.validate()) {
                              setState(() {
                                widget.data.vehicles.add({
                                  'vehicle_type': vehicleType!,
                                  'vehicle_number': vehicleNoController.text,
                                  'total_amount': amountController.text,
                                });
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004DE8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Add Vehicle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          onPressed: _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004DE8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            children: [
              const Text(
                'Next',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}
