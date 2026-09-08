import 'package:flutter/material.dart';
import 'resetpasswordscreen.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String code;
  const VerifyEmailScreen({super.key, required this.email, required this.code});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _c =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _f = List.generate(6, (_) => FocusNode());

  String get _entered => _c.map((e) => e.text.trim()).join();

  @override
  void dispose() {
    for (final x in _c) {
      x.dispose();
    }
    for (final x in _f) {
      x.dispose();
    }
    super.dispose();
  }

  void _onChanged(int i, String v) {
    if (v.isNotEmpty) {
      if (i < 5) {
        FocusScope.of(context).requestFocus(_f[i + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    } else if (i > 0) {
      FocusScope.of(context).requestFocus(_f[i - 1]);
    }
    setState(() {});
  }

  void _verify() {
    if (_entered == widget.code) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid code')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBrown,
      body: Stack(
        children: [
          Positioned(
            top: -size.width * .35,
            left: -size.width * .25,
            child: _blob(size.width * 1.1, const [Color(0xFFFFE082), kGold]),
          ),
          Positioned(
            bottom: -size.width * .4,
            right: -size.width * .3,
            child: _blob(size.width * 1.2, const [kRedSoft, Color(0xFFFFCDD2)]),
          ),
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: kBrownDark.withOpacity(.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png',
                          width: 120, height: 120, fit: BoxFit.contain),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter the 6-digit code we sent to ${'*' * (widget.email.length > 6 ? widget.email.length - 6 : 0)}${widget.email.substring(widget.email.length - (widget.email.length > 6 ? 6 : widget.email.length))}.',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(
                                height: 56,
                                child: TextField(
                                  controller: _c[i],
                                  focusNode: _f[i],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  textInputAction: i < 5
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  maxLength: 1,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: const Color(0xFFF7F7F7),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1.5),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: kGold, width: 2),
                                    ),
                                  ),
                                  onChanged: (v) => _onChanged(i, v),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRedSoft,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _entered.length == 6 ? _verify : null,
                          child: const Text(
                            'Verify & Continue',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Didn’t get the code? Resend',
                          style: TextStyle(
                            color: Colors.black54,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
