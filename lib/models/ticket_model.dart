class Ticket {
  final String vehicleNumber;
  final String vehicleType;
  final String receiptID;
  final DateTime checkInTime;

  Ticket({
    required this.vehicleNumber,
    required this.vehicleType,
    required this.receiptID,
    required this.checkInTime,
  });

  // Function to generate Receipt ID with current date-time in milliseconds
  static String generateReceiptID() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
