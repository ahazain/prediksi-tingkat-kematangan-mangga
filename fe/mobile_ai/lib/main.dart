import 'package:flutter/material.dart';
import 'pages/image_input_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ImageInputPage(),
    );
  }
}
