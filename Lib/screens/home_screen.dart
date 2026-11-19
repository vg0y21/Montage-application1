import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditorScreen(videoPath: file.path),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient kinetic studio glow
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withAlpha(55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF4D6D).withAlpha(45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PULSE STUDIO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                        ),
                        child: const Text(
                          'V1.0 • KINETIC',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'مونتاج بلمسة
مبتكرة وسريعة',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'عجلة تحكم مدارية، فلاتر سينمائية حية، دمج موسيقى، وتصدير عالي الدقة مباشرة لمعرضك.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(165),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Magnetic Orbital Start Button
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final glow = 16.0 + (_pulseCtrl.value * 18.0);
                        return GestureDetector(
                          onTap: _pickVideo,
                          child: Container(
                            width: 185,
                            height: 185,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF0077FF),
                                  Color(0xFFFF4D6D),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withAlpha(90),
                                  blurRadius: glow,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0B0F19),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _picking
                                        ? Icons.hourglass_top_rounded
                                        : Icons.add_rounded,
                                    size: 46,
                                    color: const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _picking ? 'جاري الفتح...' : 'مشروع جديد',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'اختر فيديو من المعرض',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withAlpha(140),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _FeatureChip(icon: Icons.radio_button_checked, label: 'عجلة تحكم مدارية'),
                      _FeatureChip(icon: Icons.auto_awesome, label: 'مختبر ألوان حي'),
                      _FeatureChip(icon: Icons.speed, label: 'تحكم بالسرعة'),
                      _FeatureChip(icon: Icons.music_note, label: 'دمج صوت وموسيقى'),
                      _FeatureChip(icon: Icons.hd, label: 'تصدير 1080p'),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF121622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}
