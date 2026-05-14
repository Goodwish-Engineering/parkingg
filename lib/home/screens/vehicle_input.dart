// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parking/api/checkincheckout.dart';
import 'package:parking/database/helper_class.dart';
import 'package:parking/home/models/vehicleratemodel.dart';
import 'package:parking/models/ticket_model.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final VehicleRate vehicleRate;
  final Map<String, String> parkingSlipDetails;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicleRate,
    required this.parkingSlipDetails,
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const platform = MethodChannel('com.example.test/printer');
  final DatabaseHelper _dbHelper = DatabaseHelper();
  VehicleService vehicleService = VehicleService();

  // Add TextEditingController for vehicle number input
  final TextEditingController _vcontroller = TextEditingController();

  // Variables to store data
  String vn = '';
  String rid = '';
  String vt = '';

  // Extract parking slip details
  late String heading1;
  late String heading2;
  late String heading3;
  late String heading4;
  String? footerText;
  late String firstname;
  late String lastname;
  late String id;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadAllData();
  }

  void _initializeData() async {
    // Initialize parking slip details
    heading1 = widget.parkingSlipDetails['heading1'] ?? '';
    heading2 = widget.parkingSlipDetails['heading2'] ?? '';
    heading3 = widget.parkingSlipDetails['heading3'] ?? '';
    heading4 = widget.parkingSlipDetails['heading4'] ?? '';
    footerText = widget.parkingSlipDetails['footerText'];
    id = widget.parkingSlipDetails['id'] ?? '';
    // Parse full name
    String fullName = widget.parkingSlipDetails['full_name'] ?? '';
    List<String> nameParts = fullName.split(' ');
    firstname = nameParts.isNotEmpty ? nameParts[0] : '';
    lastname = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
   
  }

  @override
  void dispose() {
    _vcontroller.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      await platform.invokeMethod('bindPrinterService');
      await platform.invokeMethod('initializePrinter');
    } catch (e) {
      print('Error initializing printer: $e');
    }
  }

  String formatDateTime(DateTime dateTime) {
    // Format: 2025-05-06 11:41:00
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Future<void> printtext({required String vehicleType}) async {
    // Validate vehicle number input
    if (_vcontroller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Please enter a vehicle number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    vn = _vcontroller.text.trim();
    rid = Ticket.generateReceiptID();
    vt = vehicleType;
    String ct = DateTime.now().toIso8601String();

    // Parse the current time into separate date and time components
    DateTime now = DateTime.now();
    String ctt = formatDateTime(now);
    String formattedDate = "${now.year}/${now.month}/${now.day}";

    // Format time in 12-hour format with AM/PM
    String hour = (now.hour % 12 == 0) ? '12' : (now.hour % 12).toString();
    String amPm = now.hour < 12 ? 'AM' : 'PM';
    String formattedTime =
        "$hour:${now.minute.toString().padLeft(2, '0')} $amPm";

    try {
      // Set printer alignment to center (1 = center)
      await platform.invokeMethod('setPrinterPrintAlignment', {'alignment': 1});

      // Print header
      await platform.invokeMethod('printText', {
        'text': '$heading1\n$heading2\n$heading3\n$heading4',
      });
      await platform.invokeMethod('setPrinterPrintFontSize', {'fontSize': 24});

      // Feed some lines
      await platform.invokeMethod('printerPerformPrint', {'feedLines': 2});

      // Print vehicle details
      String detailsText =
          'Vehicle Number: $vn\nVehicle Type: $vt\nReceipt ID: $rid\n'
          'Check-in BY: $firstname $lastname\nDate: $formattedDate\n'
          'Time: $formattedTime';

      await platform.invokeMethod('printText', {'text': detailsText});
      await platform.invokeMethod('printerPerformPrint', {'feedLines': 20});

      // Print QR code

      await platform.invokeMethod('printQRCode', {
        'data': '$vn;$vt;$rid;$ct',
        'moduleSize': 12,
        'errorCorrectionLevel': 0,
      });

      await platform.invokeMethod('printerPerformPrint', {'feedLines': 40});

      // Print footer
      if (footerText != null && footerText!.isNotEmpty) {
        await platform.invokeMethod('printText', {'text': footerText!});
      }

      // Feed paper to cut position
      await platform.invokeMethod('printerPerformPrint', {'feedLines': 85});

      // Save to local database
      await _dbHelper.insertCheckInRecord({
        'receipt_id': rid,
        'vehicle_number': vn,
        'vehicle_type': vt,
        'checkin_time': ctt,
        'checkedin_by': id,
      });

      // Clear the controller after successful print
      _vcontroller.clear();
      try {
        final checkInResponse = await vehicleService.checkIn(
          receiptId: rid,
          vehicleNumber: vn,
          vehicleType: vt,
          checkinTime: ct,
        );

        print("checkin response : $checkInResponse");
      } catch (e) {
        print("Online check-in failed, will retry later: $e");
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print('Printing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'An error occurred while printing. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(widget.vehicleRate);
    print(widget.parkingSlipDetails);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF6E93B3),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Vehicle Details",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        widget.vehicleRate.icon != null &&
                                widget.vehicleRate.icon!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  widget.vehicleRate.icon!,
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.directions_car,
                                color: Colors.black,
                                size: 30,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          widget.vehicleRate.vehicleType,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7EA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vehicle Number",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _vcontroller,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],

                            decoration: InputDecoration(
                              hintText: "Enter Vehicle No",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          printtext(
                            vehicleType: widget.vehicleRate.vehicleType,
                          );
                        },
                        icon: const Icon(Icons.print, color: Colors.white),
                        label: const Text(
                          "Print",
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004DE8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFDFDFDF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
