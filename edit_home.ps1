$content = Get-Content lib/user_home_screen.dart -Raw

$oldHome = '            decoration: const BoxDecoration(
              color: syanatBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),'

$newHome = '            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C4DFF), Color(0xFF6C3CE1), Color(0xFF5228B5)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),'

$content = $content.Replace($oldHome, $newHome)
$content | Set-Content lib/user_home_screen.dart -Encoding UTF8
