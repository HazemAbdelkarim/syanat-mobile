$content = Get-Content lib/orders_screen.dart -Raw

$oldCardStart = '      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Premium softer radius
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000), // even softer shadow
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
      child: Column('

$newCardStart = '      child: Opacity(
        opacity: status == "cancelled" ? 0.7 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: status == "cancelled" ? const Color(0xFFEF4444) : (status == "completed" ? const Color(0xFF10B981) : const Color(0xFF6C3CE1)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column('

$content = $content.Replace($oldCardStart, $newCardStart)
$content | Set-Content lib/orders_screen.dart -Encoding UTF8
