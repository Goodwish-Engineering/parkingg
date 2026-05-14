// ignore_for_file: avoid_print
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/checkout/checkout_screen.dart';
import 'package:parking/home/models/vehicleratemodel.dart';
import 'package:parking/home/screens/vehicle_input.dart';

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

  void _navigateToDetails(VehicleRate vehicleRate) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            VehicleDetailsScreen(
              vehicleRate: vehicleRate,
              parkingSlipDetails: parkingSlipDetails,
            ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  Widget _vehicleCard({
    required String? iconUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 100,
              width: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.contain,
                      // Shown while downloading (first time only)
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0B1B4D),
                        ),
                      ),
                      // Shown if URL is broken or never cached + no internet
                      errorWidget: (context, url, error) => const Icon(
                        Icons.directions_car,
                        size: 70,
                        color: Color(0xFF0B1B4D),
                      ),
                    )
                  : const Icon(
                      Icons.directions_car,
                      size: 70,
                      color: Color(0xFF0B1B4D),
                    ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadslipdetails();
    loadvehicledata();
  }

  Future<void> loadslipdetails() async {
    final details = await SecureStorage.getParkingSlipDetails();
    setState(() {
      parkingSlipDetails = details;
    });
  }

  Future<void> loadvehicledata() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get vehicle data from secure storage
      final details = await SecureStorage.getParkingRates();
      print('Vehicle data from storage: $details');

      // Parse the data into VehicleRate objects
      List<VehicleRate> rates = [];
      for (var item in details) {
        try {
          // Create VehicleRate from the map data
          rates.add(VehicleRate.fromJson(item));
        } catch (e) {
          print('Error parsing vehicle rate: $e');
        }
      }

      setState(() {
        vehicleRates = rates;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading vehicle data: $e');
      setState(() {
        errorMessage = 'Failed to load vehicle data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF668DAF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            const Text(
              "Select Vehicle for Check-In",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: loadvehicledata,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : vehicleRates.isEmpty
                  ? Center(
                      child: Text(
                        'No vehicles available',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: vehicleRates.length,
                        itemBuilder: (context, index) {
                          return _vehicleCard(
                            iconUrl: vehicleRates[index].icon,
                            label: vehicleRates[index].vehicleType,
                            onTap: () =>
                                _navigateToDetails(vehicleRates[index]),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC5100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            CheckoutScreen(
                              vehicleRates: vehicleRates,
                              parkingSlipDetails: parkingSlipDetails,
                            ),
                        transitionsBuilder: (_, __, ___, child) => child,
                      ),
                    );
                  },
                  child: const Text(
                    "Check Out",
                    style: TextStyle(
                      fontSize: 24,
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
}
