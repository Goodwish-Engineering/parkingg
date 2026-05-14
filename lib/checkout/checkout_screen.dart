// ignore_for_file: avoid_print
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking/api/checkincheckout.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/database/helper_class.dart';
import 'package:parking/home/models/vehicleratemodel.dart';
import 'package:parking/home/screens/homepage.dart';
import 'package:parking/main.dart';
import 'package:intl/intl.dart';

class CheckoutScreen extends StatefulWidget {
  final List<VehicleRate> vehicleRates;
  final Map<String, String> parkingSlipDetails;
  const CheckoutScreen({
    super.key,
    required this.parkingSlipDetails,
    required this.vehicleRates,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  static const printerChannel = MethodChannel('com.example.test/printer');
  static const scannerChannel = MethodChannel('com.example.test/scanner');

  // State variables
  Map<String, dynamic>? ticketData;
  double? parkingFee;
  bool isLoading = false;
  bool _isProcessingScan = false;
  bool _shouldShowDetails = false;
  String? apiResponseMessage;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final bool _showCamera = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final VehicleService vehicleService = VehicleService();
  int freeTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _setupScannerListener();
    _initPrinter();
    fetchfreetime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Do NOT dispose _cameraController here since it's managed by CameraManager
    super.dispose();
  }

  Future<void> fetchfreetime() async {
    final value = await SecureStorage.getFreeTime();

    setState(() {
      freeTime = value;
    });
  }

  Future<void> _initializeCamera() async {
    try {
      // Use pre-initialized camera from CameraManager
      final cameraManager = CameraManager();
      if (cameraManager.isInitialized) {
        _cameraController = cameraManager.controller;
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      } else {
        // Fallback: Initialize camera if not already initialized
        await cameraManager.initialize();
        _cameraController = cameraManager.controller;
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  Future<void> _initPrinter() async {
    try {
      await printerChannel.invokeMethod('bindPrinterService');
      await printerChannel.invokeMethod('initializePrinter');
    } catch (e) {
      print('Printer initialization error: $e');
    }
  }

  void _setupScannerListener() {
    scannerChannel.setMethodCallHandler((call) async {
      if (call.method == "onScanData") {
        final scanData = call.arguments as String;
        if (scanData.isNotEmpty) {
          _processScanData(scanData);
        }
      }
      return null;
    });

    scannerChannel.invokeMethod('startScanner');
  }

  Future<void> _processScanData(String scanData) async {
    if (_isProcessingScan) return;

    setState(() {
      _isProcessingScan = true;
      apiResponseMessage = null;
    });

    try {
      final parsedData = _parseQRCode(scanData);
      if (parsedData == null) {
        setState(() {
          apiResponseMessage = 'Invalid QR Code format';
          _shouldShowDetails = false;
        });
        return;
      }

      setState(() {
        ticketData = parsedData;
        parkingFee = calculateParkingFee(parsedData)?.toDouble();
        _shouldShowDetails = true;
      });
    } catch (e) {
      print('Scan processing error: $e');
      setState(() {
        apiResponseMessage = 'Error processing QR code: ${e.toString()}';
        _shouldShowDetails = false;
      });
    } finally {
      setState(() {
        _isProcessingScan = false;
      });
    }
  }

  Map<String, dynamic>? _parseQRCode(String data) {
    try {
      final parts = data.split(';').map((part) => part.trim()).toList();
      if (parts.length < 4) throw Exception("Invalid QR format");

      return {
        'vehicleNumber': parts[0],
        'vehicleType': parts[1],
        'receiptID': parts[2],
        'checkInTime': DateTime.parse(parts[3]),
      };
    } catch (e) {
      print("QR parsing error: $e");
      return null;
    }
  }

  double? calculateParkingFee(Map<String, dynamic> data) {
    try {
      final checkInTime = data['checkInTime'] as DateTime;
      final vehicleType = data['vehicleType'] as String;
      final now = DateTime.now();
      final duration = now.difference(checkInTime).inMinutes;

      // Find matching vehicle rate from the passed vehicleRates list
      final vehicleRate = widget.vehicleRates.firstWhere(
        (v) => v.vehicleType == vehicleType,
        orElse: () => throw Exception('Vehicle type not found'),
      );

      final useSimpleRateStructure = _hasZeroQuarterlyRate();

      if (useSimpleRateStructure) {
        final hourlyRate = vehicleRate.hourlyRate;
        final halfHourlyRate = vehicleRate.halfHourlyRate;

        if (duration <= freeTime) {
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

        if (duration <= freeTime) {
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
    if (widget.vehicleRates.isEmpty) return false;
    for (var vehicle in widget.vehicleRates) {
      if (vehicle.quarterHourlyRate == 0.0) return true;
    }
    return false;
  }

  Future<void> handleCheckoutAndPrint() async {
    if (ticketData == null || parkingFee == null) return;

    setState(() => isLoading = true);

    try {
      final id = widget.parkingSlipDetails['id'] ?? '';
      final checkoutTime = DateTime.now();
      final receiptId = ticketData!['receiptID'];
      final vehicleNumber = ticketData!['vehicleNumber'];
      final vehicleType = ticketData!['vehicleType'];
      final checkInTime = ticketData!['checkInTime'] as DateTime;
      final amount = parkingFee!;

      await _printReceipt(
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        receiptId: receiptId,
        checkInTime: checkInTime,
        checkoutTime: checkoutTime,
        amount: amount,
      );

      await _dbHelper.updateCheckOutRecord({
        'checkedout_by': id,
        'receipt_id': receiptId,
        'checkout_time': checkoutTime.toString(),
        'amount': amount,
        'checkin_time': checkInTime.toString(),
        'duration': '${checkoutTime.difference(checkInTime).inMinutes} mins',
      });

      final response = await vehicleService.checkOut(
        receiptId: receiptId,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        checkoutTime: checkoutTime.toString(),
        amount: amount,
      );

      print('Checkout response: $response');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout successful!'),
          backgroundColor: Colors.green,
        ),
      );

      gotoHome();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _printReceipt({
    required String vehicleNumber,
    required String vehicleType,
    required String receiptId,
    required DateTime checkInTime,
    required DateTime checkoutTime,
    required double amount,
  }) async {
    try {
      // Get heading details from parkingSlipDetails
      final heading1 = widget.parkingSlipDetails['heading1'] ?? '';
      final heading2 = widget.parkingSlipDetails['heading2'] ?? '';
      final heading3 = widget.parkingSlipDetails['heading3'] ?? '';
      final heading4 = widget.parkingSlipDetails['heading4'] ?? '';
      final fullName = widget.parkingSlipDetails['full_name'] ?? 'Operator';

      await printerChannel.invokeMethod('setPrinterPrintAlignment', {
        'alignment': 1,
      });
      await printerChannel.invokeMethod('setPrinterPrintFontSize', {
        'fontSize': 35,
      });
      await printerChannel.invokeMethod('printText', {
        'text': '$heading1\n$heading2\n$heading3\n$heading4',
      });
      await printerChannel.invokeMethod('printerPerformPrint', {
        'feedLines': 2,
      });

      await printerChannel.invokeMethod('setPrinterPrintFontSize', {
        'fontSize': 25,
      });
      await printerChannel.invokeMethod('printText', {
        'text':
            '''
Vehicle Number: $vehicleNumber
Vehicle Type: $vehicleType
Receipt ID: $receiptId
Check-out BY: $fullName
Check-in: ${DateFormat('yyyy/MM/dd HH:mm').format(checkInTime)}
Check-out: ${DateFormat('yyyy/MM/dd HH:mm').format(checkoutTime)}
Duration: ${checkoutTime.difference(checkInTime).inHours}h ${checkoutTime.difference(checkInTime).inMinutes.remainder(60)}m
''',
      });

      await printerChannel.invokeMethod('printerPerformPrint', {
        'feedLines': 1,
      });
      await printerChannel.invokeMethod('setPrinterPrintFontSize', {
        'fontSize': 80,
      });
      await printerChannel.invokeMethod('printText', {
        'text': 'Total: Rs $amount',
      });
      await printerChannel.invokeMethod('printerPerformPrint', {
        'feedLines': 85,
      });
    } catch (e) {
      print('Printing error: $e');
      throw Exception('Printing failed');
    }
  }

  void gotoHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Homepage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Exit Parking")),
      body: Stack(
        children: [
          // Camera preview (behind other content)
          if (_showCamera && _isCameraInitialized && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!)),

          // Semi-transparent overlay with alignment frame
          if (_showCamera)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Align QR code within frame',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Your existing content
          Column(
            children: [
              // Scanner status
              if (_isProcessingScan) LinearProgressIndicator(),

              // Main content
              Expanded(
                child: Center(
                  child: _shouldShowDetails && ticketData != null
                      ? _buildTicketDetails()
                      : Container(), // Empty container when no details to show
                ),
              ),

              // Checkout button
              if (_shouldShowDetails && ticketData != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                    ),
                    onPressed: isLoading ? null : handleCheckoutAndPrint,
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'PRINT & CHECKOUT',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketDetails() {
    final checkInTime = ticketData!['checkInTime'] as DateTime;
    final duration = DateTime.now().difference(checkInTime);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Parking Receipt',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Divider(),
              _buildDetailRow('Vehicle Number:', ticketData!['vehicleNumber']),
              _buildDetailRow('Vehicle Type:', ticketData!['vehicleType']),
              _buildDetailRow('Receipt ID:', ticketData!['receiptID']),
              _buildDetailRow(
                'Check-in Time:',
                DateFormat('MMM dd, yyyy HH:mm').format(checkInTime),
              ),
              _buildDetailRow(
                'Duration:',
                '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
              ),
              Divider(),
              Text(
                'Total Fee: Rs. ${parkingFee?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
