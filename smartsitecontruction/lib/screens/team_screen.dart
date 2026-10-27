import 'package:flutter/material.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Text(
          'Team (Coming Soon)',
          style: TextStyle(fontSize: 18, color: Color(0xFF8A93A4)),
        ),
      ),
    );
  }
}