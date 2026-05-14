// ignore_for_file: avoid_print, unused_field
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:parking/api/checkincheckout.dart';
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/database/helper_class.dart';
import 'dart:convert';
import 'package:parking/home/models/vehicleratemodel.dart';

class SearchLostVehicleScreen extends StatefulWidget {
  const SearchLostVehicleScreen({super.key});

  @override
  State<SearchLostVehicleScreen> createState() =>
      _SearchLostVehicleScreenState();
}

class _SearchLostVehicleScreenState extends State<SearchLostVehicleScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _channel = MethodChannel('com.example.test/printer');
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isOffline = false;
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  double? parkingFee;
  VehicleService vehicleService = VehicleService();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool isLoading = false;
  DateTime? checkinTime;
  String receiptId = "";
  String vehicleNumber = "";
  String vehicleType = "";
  DateTime? co;

  // Add state variables to store fetched data
  List<VehicleRate> vehicleRates = [];
  Map<String, String> parkingSlipDetails = {};

  double? calculateParkingFee(Map<String, dynamic> data) {
    try {
      final checkInTimeStr = data['checkin_time'] ?? data['checkInTime'];

      // Parse the string to DateTime if it's not already a DateTime object
      final checkInTime = checkInTimeStr is DateTime
          ? checkInTimeStr
          : DateTime.parse(checkInTimeStr);

      final vehicleType = data['vehicle_type'] as String;
      final now = DateTime.now();
      final duration = now.difference(checkInTime).inMinutes;

      // Find matching vehicle rate from vehicleRates state variable
      final vehicleRate = vehicleRates.firstWhere(
        (v) => v.vehicleType == vehicleType,
        orElse: () => throw Exception('Vehicle type not found'),
      );

      final useSimpleRateStructure = _hasZeroQuarterlyRate();

      if (useSimpleRateStructure) {
        final hourlyRate = vehicleRate.hourlyRate;
        final halfHourlyRate = vehicleRate.halfHourlyRate;

        if (duration <= 0) {
          return 0.0;
        } else if (duration <= 30) {
          return halfHourlyRate;
        } else {
          int intervals = (duration / 30).ceil();
          return ((intervals ~/ 2) * hourlyRate +
              (intervals % 2) * halfHourlyRate);
        }
      } else {
        final quarterHourlyRate = vehicleRate.quarterHourlyRate;
        final halfHourlyRate = vehicleRate.halfHourlyRate;
        final hourlyRate = vehicleRate.hourlyRate;

        if (duration <= 0) {
          return 0.0;
        } else if (duration <= 30) {
          return halfHourlyRate;
        } else if (duration <= 60) {
          return hourlyRate;
        } else {
          final fullHours = ((duration - 60) / 60).floor();
          final extraMinutes = (duration - 60) % 60;
          return (hourlyRate +
              fullHours * hourlyRate +
              ((extraMinutes / 15).ceil() * quarterHourlyRate));
        }
      }
    } catch (e) {
      print('Error calculating parking fee: $e');
      return null;
    }
  }

  bool _hasZeroQuarterlyRate() {
    if (vehicleRates.isEmpty) return false;
    for (var vehicle in vehicleRates) {
      if (vehicle.quarterHourlyRate == 0.0) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _searchVehicle() async {
    FocusScope.of(context).unfocus();
    final query = _vehicleNumberController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      parkingFee = null;
    });

    try {
      await _searchVehicleOnline(query);
      setState(() {
        _isOffline = false;
      });
    } catch (e) {
      print('Online search failed, trying offline: $e');
      await _searchVehicleOffline(query);
      setState(() {
        _isOffline = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchVehicleOnline(String query) async {
    final token = await SecureStorage.getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .get(
          Uri.parse(
            '${ApiEndpoints.baseUrl}parkinginfo/parking-details/search-vehicle/?query=$query',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        final vehicle = data[0];
        setState(() {
          _searchResults = data;
          receiptId = vehicle['receipt_id'].toString();
          vehicleNumber = vehicle['vehicle_number'].toString();
          vehicleType = vehicle['vehicle_type'];
          checkinTime = DateTime.parse(vehicle['checkin_time']);
          parkingFee = calculateParkingFee(vehicle);
        });
      }
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> _searchVehicleOffline(String query) async {
    final localResults = await _dbHelper.searchVehicleLocally(query);

    if (localResults.isEmpty) {
      throw Exception('No matching parked vehicles found locally');
    }
    setState(() {
      _searchResults = localResults.map((record) {
        return {
          'receipt_id': record['receipt_id'],
          'vehicle_number': record['vehicle_number'],
          'vehicle_type': record['vehicle_type'],
          'checkin_time': record['checkin_time'],
          'checkout_status': record['checkout_time'] != null,
          'checkedin_by': record['checkedin_by'],
        };
      }).toList();

      final vehicle = localResults[0];
      receiptId = vehicle['receipt_id'].toString();
      vehicleNumber = vehicle['vehicle_number'].toString();
      vehicleType = vehicle['vehicle_type'];
      checkinTime = DateTime.parse(vehicle['checkin_time']);
      parkingFee = calculateParkingFee(vehicle);
    });
  }

  String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Future<void> handleCheckoutAndPrint() async {
    if (parkingFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not calculate parking fee'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final heading1 = parkingSlipDetails['heading1'] ?? '';
      final heading2 = parkingSlipDetails['heading2'] ?? '';
      final heading3 = parkingSlipDetails['heading3'] ?? '';
      final heading4 = parkingSlipDetails['heading4'] ?? '';
      final fullName = parkingSlipDetails['full_name'] ?? 'Operator';
      final id = parkingSlipDetails['id'];
      co = DateTime.now();
      double amount = parkingFee!;
      DateTime now = DateTime.now();
      String ctt = formatDateTime(now);
      String checkoutDate = "${now.year}/${now.month}/${now.day}";
      String hour = (now.hour % 12 == 0) ? '12' : (now.hour % 12).toString();
      String amPm = now.hour < 12 ? 'AM' : 'PM';
      String checkoutTime =
          "$hour:${now.minute.toString().padLeft(2, '0')} $amPm";

      String checkinDate = checkinTime != null
          ? "${checkinTime!.year}/${checkinTime!.month}/${checkinTime!.day}"
          : 'Unknown';

      String checkinHour = checkinTime != null
          ? (checkinTime!.hour % 12 == 0)
                ? '12'
                : (checkinTime!.hour % 12).toString()
          : 'Unknown';

      String checkinAmPm = checkinTime != null
          ? (checkinTime!.hour < 12 ? 'AM' : 'PM')
          : '';

      String formattedCheckinTime = checkinTime != null
          ? "$checkinHour:${checkinTime!.minute.toString().padLeft(2, '0')} $checkinAmPm"
          : 'Unknown';

      String duration = 'Unknown';
      if (checkinTime != null) {
        final difference = now.difference(checkinTime!);
        duration =
            '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
      }

      await _channel.invokeMethod('bindPrinterService');
      await _channel.invokeMethod('initializePrinter');
      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 35});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 1});
      await _channel.invokeMethod('printText', {'text': heading1});
      await _channel.invokeMethod('printText', {'text': heading2});
      await _channel.invokeMethod('printText', {'text': heading3});
      await _channel.invokeMethod('printText', {'text': heading4});
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 20});
      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 25});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 0});
      await _channel.invokeMethod('printText', {
        'text':
            'Vehicle Number: $vehicleNumber\n'
            'Vehicle Type: $vehicleType\n'
            'Receipt ID: $receiptId\n'
            'Check-out BY: $fullName\n'
            'Check-in Date: $checkinDate\n'
            'Check-in Time: $formattedCheckinTime\n'
            'Check-out Date: $checkoutDate\n'
            'Check-out Time: $checkoutTime\n'
            'Duration: $duration',
      });
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 20});
      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 40});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 1});
      await _channel.invokeMethod('printText', {
        'text': 'Total fee: RS $amount',
      });
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 100});

      await _dbHelper.updateCheckOutRecord({
        'receipt_id': receiptId,
        'checkout_time': ctt.toString(),
        'amount': amount,
        'duration': duration,
        'checkedout_by': id,
      });

      final checkOutResponse = await vehicleService.checkOut(
        receiptId: receiptId,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        checkoutTime: "$co",
        amount: amount,
      );

      print(checkOutResponse);

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Checkout successful! Slip printed.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        _resetState();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during checkout'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _resetState() {
    setState(() {
      _searchResults = [];
      _vehicleNumberController.clear();
      parkingFee = null;
      receiptId = "";
      vehicleNumber = "";
      vehicleType = "";
      vehicleType = "";
      checkinTime = null;
      _isOffline = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchvehilceratesandprintdetails();
  }

  Future<void> fetchvehilceratesandprintdetails() async {
    try {
      List<dynamic> ratesData = await SecureStorage.getParkingRates();
      Map<String, String> printDetails =
          await SecureStorage.getParkingSlipDetails();

      // Convert dynamic list to VehicleRate objects
      List<VehicleRate> rates = ratesData.map((rateJson) {
        if (rateJson is Map<String, dynamic>) {
          return VehicleRate.fromJson(rateJson);
        } else {
          // If it's already a Map but not Map<String, dynamic>, convert it
          return VehicleRate.fromJson(Map<String, dynamic>.from(rateJson));
        }
      }).toList();

      setState(() {
        vehicleRates = rates;
        parkingSlipDetails = printDetails;
      });

      print('Successfully loaded ${rates.length} vehicle rates');
    } catch (e) {
      print('Error fetching vehicle rates and print details: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parking rates'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF668DAF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _vehicleNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Search Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004DE8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _searchVehicle,
                  child: const Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Loading Indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Search Results
            if (_searchResults.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final vehicle = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            color: const Color(0xFF1A2B5A),
                            child: ListTile(
                              title: Text(
                                'Vehicle: ${vehicle['vehicle_number']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Type: ${vehicle['vehicle_type']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    'Check-in: ${vehicle['checkin_time']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    'Status: ${vehicle['checkout_status'] ? 'Checked out' : 'Parked'}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (parkingFee != null)
                                    Text(
                                      'Parking Fee: Rs. $parkingFee',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: vehicle['checkout_status']
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : const Icon(
                                      Icons.timer,
                                      color: Colors.orange,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Print Slip Button
                    if (!_searchResults[0]['checkout_status'] &&
                        parkingFee != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : handleCheckoutAndPrint,
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'PRINT SLIP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // No Results Message
            if (_searchResults.isEmpty && !_isLoading)
              const Expanded(
                child: Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
