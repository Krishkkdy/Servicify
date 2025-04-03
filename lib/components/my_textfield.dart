import 'package:flutter/material.dart';

class MyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final bool isPassword;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.prefixIcon,
    this.isPassword = false,
  });

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  bool _isFocused = false;
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? const Color(0xFF4E54C8) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? const Color(0xFF4E54C8).withOpacity(0.1)
                  : Colors.transparent,
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Focus(
          onFocusChange: (hasFocus) {
            setState(() {
              _isFocused = hasFocus;
            });
          },
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF4E54C8),
            ),
            decoration: InputDecoration(
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused ? const Color(0xFF4E54C8) : Colors.grey,
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color:
                            _isFocused ? const Color(0xFF4E54C8) : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.all(20),
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
