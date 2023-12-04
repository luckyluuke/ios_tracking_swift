import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IOS TRACKING',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: InkWell(
        onTap: (){

        },
        child: Text(
            "iOS event listener",
            style: GoogleFonts.inter(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign:TextAlign.center
        ),
      ),
    );
  }
}

