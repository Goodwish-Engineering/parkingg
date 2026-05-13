class VehicleType {
  final int id;
  final String vehicleType;
  final String icon;

  VehicleType({
    required this.id,
    required this.vehicleType,
    required this.icon,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'],
      vehicleType: json['vehicle_type'],
      icon: json['icon'],
    );
  }
}
