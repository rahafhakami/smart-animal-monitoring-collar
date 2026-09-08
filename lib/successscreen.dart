import 'package:flutter/material.dart';
import 'LoginPage.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                height: 220,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 199, 115, 12),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(100),
                    bottomRight: Radius.circular(100),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 2, 100, 212),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'نجاح العملية',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'تمت العملية بنجاح ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontFamily: 'Tajawal'),
                ),
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color.fromARGB(255, 251, 152, 3), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
                child: const Text(
                  'الانتقال إلى تسجيل الدخول',
                  style: TextStyle(
                    color: Color.fromARGB(255, 251, 152, 3),
                    fontSize: 16,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
