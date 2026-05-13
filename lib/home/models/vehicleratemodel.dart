class VehicleRate {
  final int id;
  final String vehicleType;
  final String? icon;
  final double hourlyRate;
  final double halfHourlyRate;
  final double quarterHourlyRate;
  final bool status;

  VehicleRate({
    required this.id,
    required this.vehicleType,
    this.icon,
    required this.hourlyRate,
    required this.halfHourlyRate,
    required this.quarterHourlyRate,
    required this.status,
  });

  factory VehicleRate.fromJson(Map<String, dynamic> json) {
    return VehicleRate(
      id: json['id'],
      vehicleType: json['vehicle_type'],
      icon: json['icon'],
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      halfHourlyRate: (json['half_hourly_rate'] as num).toDouble(),
      quarterHourlyRate: (json['quarter_hourly_rate'] as num).toDouble(),
      status: json['status'],
    );
  }

  @override
  String toString() {
    return 'VehicleRate('
        'id: $id, '
        'vehicleType: $vehicleType, '
        'icon: $icon, '
        'hourlyRate: $hourlyRate, '
        'halfHourlyRate: $halfHourlyRate, '
        'quarterHourlyRate: $quarterHourlyRate, '
        'status: $status'
        ')';
  }
}
