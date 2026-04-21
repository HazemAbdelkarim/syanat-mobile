$content = Get-Content lib/orders_screen.dart -Raw

$oldCardEnd = '                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),'

$newCardEnd = '                ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: const Color(0x0F000000),
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),'

$content = $content.Replace($oldCardEnd, $newCardEnd)
$content | Set-Content lib/orders_screen.dart -Encoding UTF8
