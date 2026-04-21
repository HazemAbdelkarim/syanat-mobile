$content = Get-Content lib/orders_screen.dart -Raw
$oldEnd = '                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }'
$newEnd = '                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ]
            ),
          ),
          ),
          ]
          )
          )
          )
          ),
      ),
    );
  }'
$content = $content.Replace($oldEnd, $newEnd)
$content | Set-Content lib/orders_screen.dart -Encoding UTF8
