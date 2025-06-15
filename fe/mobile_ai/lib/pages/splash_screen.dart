import 'package:flutter/material.dart';
import 'image_input_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();

    // Fade out setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _opacity = 0.0);

      // Navigasi ke halaman utama setelah efek memudar selesai
      Future.delayed(const Duration(milliseconds: 800), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ImageInputPage()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(63, 81, 181, 1), // Deep Indigo
              Color.fromRGBO(68, 138, 255, 1) // Light Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/mango.png',
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Deteksi Mangga",
                  style: TextStyle(
                    fontFamily: "Chillax",
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
