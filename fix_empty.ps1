$content = Get-Content lib/orders_screen.dart -Raw

$oldEmptyState = 'Widget _buildEmptyState({required IconData icon, required String label, required bool isEn}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _syanatBlue.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 72, color: _syanatBlue.withOpacity(0.7)),
              ),
              const SizedBox(height: 32),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isEn 
                    ? "When you place an order, it will appear here." 
                    : "عندما تقوم بتقديم طلب، سيظهر هنا.",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }'

$newEmptyState = 'class _FloatingEmptyIcon extends StatefulWidget {
  final IconData icon;
  const _FloatingEmptyIcon({required this.icon});
  @override
  State<_FloatingEmptyIcon> createState() => _FloatingEmptyIconState();
}

class _FloatingEmptyIconState extends State<_FloatingEmptyIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(color: Color(0xFFF3EEFF), shape: BoxShape.circle),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(widget.icon, size: 32, color: Color(0xFF6C3CE1)),
          ),
        ),
      ),
    );
  }
}

  Widget _buildEmptyState({required IconData icon, required String label, required bool isEn}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FloatingEmptyIcon(icon: icon),
            const SizedBox(height: 32),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isEn ? "When you place an order, it will appear here." : "عندما تقوم بتقديم طلب، سيظهر هنا.",
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () { /* Navigate to services */ },
              child: Text(isEn ? "Browse Services" : "تصفح الخدمات", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          ],
        ),
      ),
    );
  }'

$content = $content.Replace($oldEmptyState, $newEmptyState)

$content | Set-Content lib/orders_screen.dart -Encoding UTF8
