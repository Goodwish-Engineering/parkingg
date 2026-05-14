// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/checkout/checkout_screen.dart';
import 'package:parking/home/models/vehicleratemodel.dart';
import 'package:parking/home/screens/search_vehicle.dart';
import 'package:parking/home/screens/vehicle_input.dart';
import 'package:parking/home/screens/vehiclecard.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<VehicleRate> vehicleRates = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, String> parkingSlipDetails = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSlipDetails(), _loadVehicleData()]);
  }

  Future<void> _loadSlipDetails() async {
    final details = await SecureStorage.getParkingSlipDetails();
    if (mounted) setState(() => parkingSlipDetails = details);
  }

  Future<void> _loadVehicleData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      final details = await SecureStorage.getParkingRates();
      final rates = <VehicleRate>[];
      for (final item in details) {
        try {
          rates.add(VehicleRate.fromJson(item));
        } catch (e) {
          print('Parse error: $e');
        }
      }
      if (mounted) {
        setState(() {
          vehicleRates = rates;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load vehicle data';
          isLoading = false;
        });
      }
    }
  }

  void _navigateToDetails(VehicleRate vehicleRate) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => VehicleDetailsScreen(
          vehicleRate: vehicleRate,
          parkingSlipDetails: parkingSlipDetails,
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  void _navigateToCheckout() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => CheckoutScreen(
          vehicleRates: vehicleRates,
          parkingSlipDetails: parkingSlipDetails,
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF668DAF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // // ── Title ──────────────────────────────────────────────────────
            // const Padding(
            //   padding: EdgeInsets.only(top: 16, bottom: 14),
            //   child: Text(
            //     'Select Vehicle for Check-In',
            //     style: TextStyle(
            //       fontSize: 18,
            //       fontWeight: FontWeight.w700,
            //       color: Colors.white,
            //     ),
            //   ),
            // ),
            SizedBox(height: 20),
            // ── Vehicle Cards (flex 3) ─────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildVehicleGrid(),
              ),
            ),

            // ── Search Section (flex 4) ────────────────────────────────────
            Expanded(
              flex: 5,
              child: SearchVehicleWidget(
                vehicleRates: vehicleRates,
                parkingSlipDetails: parkingSlipDetails,
              ),
            ),

            // ── Checkout Button (fixed) ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC5100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: vehicleRates.isEmpty ? null : _navigateToCheckout,
                  child: const Text(
                    'Check Out',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleGrid() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 36),
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadVehicleData,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (vehicleRates.isEmpty) {
      return const Center(
        child: Text(
          'No vehicles available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: vehicleRates.length.clamp(0, 2), // cap at 2 as required
      itemBuilder: (context, index) => VehicleCardWidget(
        vehicleRate: vehicleRates[index],
        onTap: () => _navigateToDetails(vehicleRates[index]),
      ),
    );
  }
}
