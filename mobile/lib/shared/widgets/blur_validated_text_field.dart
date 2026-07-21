import 'package:flutter/material.dart';

/// A [TextFormField] that shows its validation error as soon as the user
/// leaves the field (on blur), instead of only when the form is submitted.
///
/// After the first blur the field re-validates on every keystroke, so the
/// error message clears the moment the input becomes valid. Untouched fields
/// stay pristine until the form-level `validate()` runs on submit.
class BlurValidatedTextField extends StatefulWidget {
  const BlurValidatedTextField({
    super.key,
    required this.controller,
    this.validator,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onFieldSubmitted;

  /// Called on every keystroke, for callers that need to react to the text
  /// as it is typed (e.g. showing a conditional hint).
  final ValueChanged<String>? onChanged;

  @override
  State<BlurValidatedTextField> createState() => _BlurValidatedTextFieldState();
}

class _BlurValidatedTextFieldState extends State<BlurValidatedTextField> {
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  /// True once the user has focused and left the field at least once.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    // Field lost focus: validate it now and keep re-validating on change
    // (via autovalidateMode below) so the error clears once fixed.
    setState(() => _touched = true);
    _fieldKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: _fieldKey,
      focusNode: _focusNode,
      controller: widget.controller,
      validator: widget.validator,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autovalidateMode: _touched
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
    );
  }
}
