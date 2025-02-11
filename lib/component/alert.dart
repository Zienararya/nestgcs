import 'package:flutter/material.dart';
import 'dart:async';

class Alert extends StatefulWidget {
  final Color color;
  final String title;
  final String description;
  final VoidCallback onApply;

  const Alert({
    super.key,
    required this.color,
    required this.title,
    required this.description,
    required this.onApply,
  });

  @override
  State<Alert> createState() => _AlertState();
}

class _AlertState extends State<Alert> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _showAlert();
    _startTimer();
  }

  void _showAlert() {
    setState(() {
      _isVisible = true;
    });
  }

  void _hideAlert() {
    setState(() {
      _isVisible = false;
    });
    widget.onApply();
  }

  void _startTimer() {
    Timer(Duration(seconds: 5), () {
      if (mounted) {
        _hideAlert();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      right: _isVisible ? 20 : -300,
      top: 80,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 10,
            ),
            Text(widget.description, style: TextStyle(color: Colors.white)),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _hideAlert,
              child: Text("Apply"),
            )
          ],
        ),
      ),
    );
  }
}
