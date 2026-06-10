// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:parking/api/checkincheckout.dart';
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/database/helper_class.dart';
import 'package:parking/home/models/vehicleratemodel.dart';

class SearchVehicleWidget extends StatefulWidget {
  final List<VehicleRate> vehicleRates;
  final Map<String, String> parkingSlipDetails;

  const SearchVehicleWidget({
    super.key,
    required this.vehicleRates,
    required this.parkingSlipDetails,
  });

  @override
  State<SearchVehicleWidget> createState() => _SearchVehicleWidgetState();
}

class _SearchVehicleWidgetState extends State<SearchVehicleWidget>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.example.test/printer');
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isSearching = false;
  bool _isPrinting = false;
  bool _isOffline = false;
  Map<String, dynamic>? _result;
  double? _parkingFee;
  String _errorMsg = '';

  // Parsed result fields
  String _receiptId = '';
  String _vehicleNumber = '';
  String _vehicleType = '';
  DateTime? _checkinTime;
  int freeTime = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    fetchfreetime();
    _initPrinter();
  }

  // Bind + initialize the printer once when the screen opens, so each
  // checkout doesn't pay the bind/init cost again.
  Future<void> _initPrinter() async {
    try {
      await _channel.invokeMethod('bindPrinterService');
      await _channel.invokeMethod('initializePrinter');
    } catch (e) {
      print('Printer init error: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Fee Calculation ──────────────────────────────────────────────────────
  Future<void> fetchfreetime() async {
    final value = await SecureStorage.getFreeTime();

    setState(() {
      freeTime = value;
    });
  }

  double? _calculateFee(Map<String, dynamic> data) {
    try {
      final raw = data['checkin_time'] ?? data['checkInTime'];
      DateTime checkIn;
      if (raw is DateTime) {
        checkIn = raw.isUtc ? raw.toLocal() : raw;
      } else {
        final parsed = DateTime.parse(raw as String);
        checkIn = parsed.isUtc ? parsed.toLocal() : parsed; // ← key fix
      }
      final type = data['vehicle_type'] as String;
      final now = DateTime.now();
      final duration = now.difference(checkIn).inMinutes;

      final rate = widget.vehicleRates.firstWhere(
        (v) => v.vehicleType == type,
        orElse: () => throw Exception('Vehicle type not found'),
      );
      final useSimpleRateStructure = rate.quarterHourlyRate == 0;
      if (useSimpleRateStructure) {
        if (duration <= freeTime) return 0;
        if (duration <= 30) return rate.halfHourlyRate;
        final intervals = (duration / 30).ceil();
        return (intervals ~/ 2) * rate.hourlyRate +
            (intervals % 2) * rate.halfHourlyRate;
      } else {
        final quarterHourlyRate = rate.quarterHourlyRate;
        final halfHourlyRate = rate.halfHourlyRate;
        final hourlyRate = rate.hourlyRate;

        if (duration <= 0) {
          return 0.0;
        }

        // Number of completed hours
        final completedHours = duration ~/ 60;

        // Remaining minutes after full hours
        final remainingMinutes = duration % 60;

        double total = 0;

        // Base hourly charge
        if (remainingMinutes == 0) {
          total = completedHours * hourlyRate;
        } else {
          total = (completedHours + 1) * hourlyRate;
        }

        // Adjust slab pricing
        if (remainingMinutes > 0 && remainingMinutes <= 15) {
          total = (completedHours * hourlyRate) + quarterHourlyRate;
        } else if (remainingMinutes > 15 && remainingMinutes <= 30) {
          total = (completedHours * hourlyRate) + halfHourlyRate;
        } else if (remainingMinutes > 30) {
          total = (completedHours + 1) * hourlyRate;
        }

        // Minimum 1 hour charge
        if (total < hourlyRate) {
          total = hourlyRate;
        }

        return total;
      }
    } catch (e) {
      print('Fee calc error: $e');
      return null;
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();

    setState(() {
      _isSearching = true;
      _result = null;
      _parkingFee = null;
      _errorMsg = '';
      _isOffline = false;
    });
    _animController.reset();

    try {
      await _searchOnline(query);
      _isOffline = false;
    } catch (_) {
      try {
        await _searchOffline(query);
        _isOffline = true;
      } catch (e) {
        setState(() => _errorMsg = 'No vehicle found for "$query"');
      }
    } finally {
      setState(() => _isSearching = false);
      if (_result != null) _animController.forward();
    }
  }

  Future<void> _searchOnline(String query) async {
    final token = await SecureStorage.getAccessToken();
    final resp = await http
        .get(
          Uri.parse(
            '${ApiEndpoints.baseUrl}parkinginfo/parking-details/search-vehicle/?query=$query',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = json.decode(resp.body);
      if (data is List && data.isNotEmpty) {
        _applyResult(data[0]);
      } else {
        throw Exception('Empty result');
      }
    } else {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  Future<void> _searchOffline(String query) async {
    final local = await _dbHelper.searchVehicleLocally(query);
    if (local.isEmpty) throw Exception('Not found locally');
    _applyResult({
      'receipt_id': local[0]['receipt_id'],
      'vehicle_number': local[0]['vehicle_number'],
      'vehicle_type': local[0]['vehicle_type'],
      'checkin_time': local[0]['checkin_time'],
      'checkout_status': local[0]['checkout_time'] != null,
      'checkedin_by': local[0]['checkedin_by'],
    });
  }

  void _applyResult(Map<String, dynamic> vehicle) {
    final raw = vehicle['checkin_time']?.toString() ?? '';
    DateTime? parsedTime;

    if (raw.isNotEmpty) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        // Convert UTC to local (Nepal = UTC+5:45)
        parsedTime = dt.isUtc ? dt.toLocal() : dt.toLocal();
      }
    }

    setState(() {
      _result = vehicle;
      _receiptId = vehicle['receipt_id'].toString();
      _vehicleNumber = vehicle['vehicle_number'].toString();
      _vehicleType = vehicle['vehicle_type'].toString();
      _checkinTime = parsedTime;
      _parkingFee = _calculateFee(vehicle);
    });
  }

  void _clear() {
    _animController.reverse().then((_) {
      setState(() {
        _result = null;
        _parkingFee = null;
        _errorMsg = '';
        _controller.clear();
      });
    });
  }

  // ─── Checkout & Print ─────────────────────────────────────────────────────

  Future<void> _handleCheckoutAndPrint({required String paymentMethod}) async {
    if (_parkingFee == null) return;
    setState(() => _isPrinting = true);

    try {
      final slip = widget.parkingSlipDetails;
      final now = DateTime.now();

      final String checkoutDate = '${now.year}/${now.month}/${now.day}';
      final String checkoutTime =
          '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour < 12 ? 'AM' : 'PM'}';
      final String checkinDate = _checkinTime != null
          ? '${_checkinTime!.year}/${_checkinTime!.month}/${_checkinTime!.day}'
          : 'Unknown';
      final String checkinHour = _checkinTime != null
          ? '${_checkinTime!.hour % 12 == 0 ? 12 : _checkinTime!.hour % 12}:${_checkinTime!.minute.toString().padLeft(2, '0')} ${_checkinTime!.hour < 12 ? 'AM' : 'PM'}'
          : 'Unknown';
      final String duration = _checkinTime != null
          ? '${now.difference(_checkinTime!).inHours}h ${now.difference(_checkinTime!).inMinutes.remainder(60)}m'
          : 'Unknown';
      final String ctt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 35});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 1});
      for (final h in ['heading1', 'heading2', 'heading3', 'heading4']) {
        if ((slip[h] ?? '').isNotEmpty) {
          await _channel.invokeMethod('printText', {'text': slip[h]});
        }
      }
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 20});
      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 25});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 0});
      await _channel.invokeMethod('printText', {
        'text':
            'Vehicle Number: $_vehicleNumber\n'
            'Vehicle Type: $_vehicleType\n'
            'Receipt ID: $_receiptId\n'
            'Check-out By: ${slip['full_name'] ?? 'Operator'}\n'
            'Check-in Date: $checkinDate\n'
            'Check-in Time: $checkinHour\n'
            'Check-out Date: $checkoutDate\n'
            'Check-out Time: $checkoutTime\n'
            'Duration: $duration\n'
            'Paid by: ${paymentMethod == 'QR' ? 'QR' : 'Cash'}',
      });
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 20});
      await _channel.invokeMethod('setPrinterPrintFontSize', {'fontSize': 40});
      await _channel.invokeMethod('setPrinterPrintAlignment', {'alignment': 1});
      await _channel.invokeMethod('printText', {
        'text': 'Total Fee: RS $_parkingFee',
      });
      await _channel.invokeMethod('printerPerformPrint', {'feedLines': 100});

      await _dbHelper.updateCheckOutRecord({
        'receipt_id': _receiptId,
        'checkout_time': ctt,
        'amount': _parkingFee,
        'duration': duration,
        'checkedout_by': slip['id'],
        'payment_method': paymentMethod,
      });

      await VehicleService().checkOut(
        receiptId: _receiptId,
        vehicleNumber: _vehicleNumber,
        vehicleType: _vehicleType,
        checkoutTime: now.toString(),
        amount: _parkingFee!,
        paymentMethod: paymentMethod,
      );

      if (!mounted) return;
      _showSnack(
        '✅ Checkout successful — '
        '${paymentMethod == 'QR' ? 'QR' : 'Cash'} '
        'RS ${_parkingFee!.toStringAsFixed(0)}',
        Colors.green,
      );
      Future.delayed(const Duration(seconds: 1), _clear);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error during checkout. Please retry.', Colors.red);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Check-Out Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              _SearchBar(
                controller: _controller,
                focusNode: _focusNode,
                isSearching: _isSearching,
                onSearch: _search,
                onClear: _clear,
                hasResult: _result != null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ErrorChip(message: _errorMsg),
          ),
        if (_result != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _VehicleResultCard(
                    result: _result!,
                    parkingFee: _parkingFee,
                    checkinTime: _checkinTime,
                    isOffline: _isOffline,
                    isPrinting: _isPrinting,
                    onCheckout: (method) =>
                        _handleCheckoutAndPrint(paymentMethod: method),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final bool hasResult;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.hasResult,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .3), width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter vehicle number…',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          if (hasResult)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white60,
                  size: 18,
                ),
              ),
            ),
          GestureDetector(
            onTap: isSearching ? null : onSearch,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF004DE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isSearching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  final String message;
  const _ErrorChip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: .4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final double? parkingFee;
  final DateTime? checkinTime;
  final bool isOffline;
  final bool isPrinting;
  final void Function(String paymentMethod) onCheckout;

  const _VehicleResultCard({
    required this.result,
    required this.parkingFee,
    required this.checkinTime,
    required this.isOffline,
    required this.isPrinting,
    required this.onCheckout,
  });

  bool get _isCheckedOut => result['checkout_status'] == true;

  String get _duration {
    if (checkinTime == null) return '—';
    final diff = DateTime.now().difference(checkinTime!);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }

  String get _checkinFormatted {
    if (checkinTime == null) return '—';
    final h = checkinTime!.hour % 12 == 0 ? 12 : checkinTime!.hour % 12;
    final m = checkinTime!.minute.toString().padLeft(2, '0');
    final ap = checkinTime!.hour < 12 ? 'AM' : 'PM';
    return '${checkinTime!.day}/${checkinTime!.month}/${checkinTime!.year}  $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F52).withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: .12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result['vehicle_number'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isCheckedOut
                        ? Colors.green.withValues(alpha: .2)
                        : Colors.blueAccent.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isCheckedOut
                          ? Colors.green.withValues(alpha: .5)
                          : Colors.blueAccent.withValues(alpha: .5),
                    ),
                  ),
                  child: Text(
                    _isCheckedOut ? 'CHECKED OUT' : 'PARKED',
                    style: TextStyle(
                      color: _isCheckedOut
                          ? Colors.greenAccent
                          : Colors.blueAccent[100],
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Info rows ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoRow(
                    icon: Icons.category_rounded,
                    label: 'Type',
                    value: result['vehicle_type'].toString(),
                  ),
                  _InfoRow(
                    icon: Icons.login_rounded,
                    label: 'Check-in',
                    value: _checkinFormatted,
                  ),
                  _InfoRow(
                    icon: Icons.timer_rounded,
                    label: 'Duration',
                    value: _duration,
                  ),
                ],
              ),
            ),
          ),

          // ── Fee + Button ──
          if (!_isCheckedOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL FEE',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            parkingFee != null
                                ? 'RS ${parkingFee!.toStringAsFixed(0)}'
                                : '—',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Tap how the\ncustomer paid',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PayButton(
                          label: 'CASH',
                          icon: Icons.payments,
                          color: Colors.green,
                          isBusy: isPrinting,
                          onTap: () => onCheckout('CASH'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PayButton(
                          label: 'QR',
                          icon: Icons.qr_code,
                          color: const Color(0xFF004DE8),
                          isBusy: isPrinting,
                          onTap: () => onCheckout('QR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isBusy;
  final VoidCallback onTap;

  const _PayButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isBusy ? null : onTap,
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(child: DottedDivider()),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 5).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }
}
