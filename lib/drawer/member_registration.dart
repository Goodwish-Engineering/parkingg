// Screen 1: Member Registration
import 'package:flutter/material.dart';
import 'package:parking/drawer/add_member.dart';

class MemberRegistrationScreen extends StatefulWidget {
  final RegistrationData data;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool isFirstPage;

  const MemberRegistrationScreen({
    super.key,
    required this.data,
    required this.onNext,
    required this.onPrevious,
    this.isFirstPage = false,
  });

  @override
  State<MemberRegistrationScreen> createState() =>
      _MemberRegistrationScreenState();
}

class _MemberRegistrationScreenState extends State<MemberRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _vatController;
  late final TextEditingController _shopController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.name);
    _contactController = TextEditingController(text: widget.data.contactNo);
    _vatController = TextEditingController(text: widget.data.vatRegistrationNo);
    _shopController = TextEditingController(text: widget.data.shopNo);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _vatController.dispose();
    _shopController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      widget.data.name = _nameController.text;
      widget.data.contactNo = _contactController.text;
      widget.data.vatRegistrationNo = _vatController.text;
      widget.data.shopNo = _shopController.text;
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Member Registration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                _buildLabel('Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameController,
                  hintText: 'Enter name',
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter name' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Contact No'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _contactController,
                  hintText: 'Enter no',
                  keyboardType: TextInputType.number,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter contact number'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('VAT Registration No'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _vatController,
                  hintText: 'Enter VAT registration number',
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter VAT registration number'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Shop No'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _shopController,
                  hintText: 'Enter shop number',
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter shop number'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildNavigationButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFFC0C0C0)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isFirstPage)
          ElevatedButton(
            onPressed: widget.onPrevious,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 14),
                const SizedBox(width: 8),
                const Text(
                  'Previous',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton(
          onPressed: _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004DE8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            children: [
              const Text(
                'Next',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}
