import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

/// Reusable international phone input. Stores/returns the number in
/// E.164 format (e.g. +94771234567) so it's consistent regardless of
/// which country the business or client is in (GLOBAL_READINESS §1.C).
class PhoneInputField extends StatelessWidget {
  final String initialValue;
  final String initialCountryCode;
  final ValueChanged<String> onChanged;
  final String labelText;

  const PhoneInputField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.initialCountryCode = 'LK',
    this.labelText = 'Phone (optional)',
  });

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: initialValue.isEmpty ? initialCountryCode : null,
      initialValue: initialValue.isEmpty ? null : initialValue,
      decoration: InputDecoration(labelText: labelText),
      disableLengthCheck: true,
      onChanged: (phone) => onChanged(phone.completeNumber),
    );
  }
}