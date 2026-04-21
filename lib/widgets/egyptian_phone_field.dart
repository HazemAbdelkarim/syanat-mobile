import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Strips `+20`, leading `20`, or a leading `0` from [raw] and returns the
/// last 10 digits. Returns an empty string when the normalized result is
/// shorter than 10 digits or non-numeric.
///
/// Accepts: `+201023645696`, `201023645696`, `01023645696`, `1023645696`,
/// with or without spaces/dashes. Output for all four: `1023645696`.
String normalizeEgyptianLocal(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (local.startsWith('20') && local.length > 10) {
    local = local.substring(2);
  }
  if (local.length == 11 && local.startsWith('0')) {
    local = local.substring(1);
  }
  if (local.length != 10) return '';
  return local;
}

/// Prepends `+20` to a 10-digit local part, producing the canonical E.164
/// representation. Returns an empty string if [local] isn't exactly 10 digits.
String egyptianToE164(String local) {
  final String digits = local.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 10) return '';
  return '+20$digits';
}

/// `true` when [local] is exactly 10 digits starting with a valid Egyptian
/// mobile carrier prefix (10, 11, 12, 15).
bool isValidEgyptianLocal(String local) =>
    RegExp(r'^1[0125]\d{8}$').hasMatch(local);

/// Validator for the 10-digit local part. Returns an error string on failure,
/// or `null` when the value is valid. Set [required] to `false` to accept an
/// empty field.
String? validateEgyptianLocal(
  String? value, {
  required bool isEn,
  bool required = true,
}) {
  final String local = (value ?? '').trim();
  if (local.isEmpty) {
    if (!required) return null;
    return isEn
        ? 'Enter a 10-digit Egyptian mobile number (e.g. 1012345678)'
        : 'أدخل رقم هاتف مصري من 10 أرقام (مثال: 1012345678)';
  }
  if (!isValidEgyptianLocal(local)) {
    return isEn
        ? 'Enter a 10-digit Egyptian mobile number (e.g. 1012345678)'
        : 'أدخل رقم هاتف مصري من 10 أرقام (مثال: 1012345678)';
  }
  return null;
}

/// A phone input with a non-editable `🇪🇬 +20` prefix, digits-only entry,
/// and built-in validation of the 10-digit local part. The controller holds
/// only the local part (e.g. `1023645696`); call [egyptianToE164] before
/// sending the value to a backend.
class EgyptianPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool isEn;
  final String? labelText;
  final bool required;

  /// Optional override styling. When `null`, a neutral OutlineInputBorder is
  /// used. Callers that already wrap the field in a custom Container can pass
  /// [InputBorder.none] and [filled]=false.
  final InputDecoration? decoration;

  /// When true, validation runs inline via the parent `Form`. When false, the
  /// caller is responsible for manual validation via [validateEgyptianLocal].
  final bool useFormValidator;

  const EgyptianPhoneField({
    super.key,
    required this.controller,
    required this.isEn,
    this.labelText,
    this.required = true,
    this.decoration,
    this.useFormValidator = true,
  });

  @override
  Widget build(BuildContext context) {
    final InputDecoration baseDecoration = decoration ??
        InputDecoration(
          labelText: labelText ?? (isEn ? 'Phone Number' : 'رقم الهاتف'),
          hintText: '1012345678',
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        );

    final Widget prefix = Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('🇪🇬', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '+20',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      textDirection: TextDirection.ltr,
      validator: useFormValidator
          ? (String? v) =>
              validateEgyptianLocal(v, isEn: isEn, required: required)
          : null,
      decoration: baseDecoration.copyWith(
        prefixIcon: prefix,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
