import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parking/home/models/vehicleratemodel.dart';

class VehicleCardWidget extends StatelessWidget {
  final VehicleRate vehicleRate;
  final VoidCallback onTap;

  const VehicleCardWidget({
    super.key,
    required this.vehicleRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _buildIcon(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  vehicleRate.vehicleType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF0B1B4D),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final iconUrl = vehicleRate.icon;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0B1B4D),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.directions_car,
          size: 52,
          color: Color(0xFF0B1B4D),
        ),
      );
    }
    return const Icon(
      Icons.directions_car,
      size: 52,
      color: Color(0xFF0B1B4D),
    );
  }
}