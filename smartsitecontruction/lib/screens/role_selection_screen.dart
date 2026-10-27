import 'package:flutter/material.dart';
import 'material_request_screen.dart';
import 'dashboard_screen.dart';

// Hardcoded for MVP — replace with real auth in v2
const _kProjectId = 'e9027d02-0d3e-496f-8c96-d760fd3469f3';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Palette
  static const _bg        = Color(0xFF0F1117);
  static const _surface   = Color(0xFF1A1D23);
  static const _border    = Color(0xFF2C3140);
  static const _primary   = Color(0xFF4F6EF7);
  static const _accent    = Color(0xFF00C896);
  static const _textLight = Color(0xFFECEFF4);
  static const _textMuted = Color(0xFF8A93A4);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goForeman() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const MaterialRequestScreen(projectId: _kProjectId),
        ),
      );

  void _goManager() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DashboardScreen(projectId: _kProjectId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Subtle grid background ───────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ── Glow blobs ───────────────────────────────────────────
          Positioned(
            top: -120, left: -100,
            child: _GlowBlob(color: _primary.withOpacity(0.18), size: 420),
          ),
          Positioned(
            bottom: -100, right: -80,
            child: _GlowBlob(color: _accent.withOpacity(0.12), size: 360),
          ),

          // ── Main content ─────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo mark
                        _LogoMark(),
                        const SizedBox(height: 28),

                        // Title
                        const Text(
                          'Smart Site',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textLight,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Construction ERP — MVP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Divider line
                        Container(
                          width: 40, height: 2,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Label above cards
                        const Text(
                          'SELECT YOUR ROLE',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Role cards ───────────────────────────────
                        _RoleCard(
                          icon: Icons.engineering_rounded,
                          iconBg: const Color(0xFF1E2740),
                          iconColor: _primary,
                          title: 'Foreman Mode',
                          subtitle: 'Request materials on-site.\nOptimised for mobile.',
                          badgeLabel: 'MOBILE',
                          badgeColor: _primary,
                          borderColor: _primary.withOpacity(0.35),
                          onTap: _goForeman,
                        ),
                        const SizedBox(height: 16),
                        _RoleCard(
                          icon: Icons.insert_chart_rounded,
                          iconBg: const Color(0xFF102B25),
                          iconColor: _accent,
                          title: 'Manager Mode',
                          subtitle: 'Approve requests & track\nP&L in real-time.',
                          badgeLabel: 'DASHBOARD',
                          badgeColor: _accent,
                          borderColor: _accent.withOpacity(0.3),
                          onTap: _goManager,
                        ),

                        const SizedBox(height: 48),

                        // Footer note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_outline_rounded,
                                size: 13, color: Color(0xFF555B6A)),
                            SizedBox(width: 6),
                            Text(
                              'Auth & roles are mocked for MVP.',
                              style: TextStyle(
                                color: Color(0xFF555B6A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const _surface  = Color(0xFF1A1D23);
  static const _textLight = Color(0xFFECEFF4);
  static const _textMuted = Color(0xFF8A93A4);

  @override
  Widget build(BuildContext context) {
    final elevated = _hovered || _pressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, elevated ? -3.0 : 0.0),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: elevated
                ? _surface.withOpacity(0.95)
                : _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: elevated
                  ? widget.borderColor
                  : const Color(0xFF2C3140),
              width: elevated ? 1.5 : 1,
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: widget.iconColor.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon,
                    color: widget.iconColor, size: 26),
              ),
              const SizedBox(width: 18),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: _textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Badge(
                          label: widget.badgeLabel,
                          color: widget.badgeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: elevated ? widget.iconColor : const Color(0xFF555B6A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      );
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2C3140)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F6EF7).withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.construction_rounded,
          color: Color(0xFF4F6EF7),
          size: 32,
        ),
      );
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.8)],
        ),
      );
}

// ── Subtle dot-grid background ────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C3140).withOpacity(0.45)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}