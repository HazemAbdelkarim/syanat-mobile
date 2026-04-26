import 'dart:typed_data';

/// Image formats accepted by the technician's Approve Payment screen.
enum ImageFormat { jpeg, png, heic, webp }

/// Returns the image format detected from the magic-byte signature of
/// [bytes], or null if the bytes do not match any supported image format.
///
/// Browsers treat `<input accept="image/*">` as advisory — a user (or
/// a malicious actor) can feed a renamed .mp4 whose extension and
/// MIME header both say JPEG. The only reliable client-side check is
/// inspecting the file's binary signature, which this function does.
///
/// Requires at least 12 bytes. Anything shorter is rejected.
ImageFormat? detectImageFormat(Uint8List bytes) {
  if (bytes.length < 12) return null;

  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return ImageFormat.png;
  }

  // WebP: bytes 0-3 'RIFF', bytes 8-11 'WEBP'
  if (bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46 && // F
      bytes[8] == 0x57 && // W
      bytes[9] == 0x45 && // E
      bytes[10] == 0x42 && // B
      bytes[11] == 0x50) { // P
    return ImageFormat.webp;
  }

  // HEIC / HEIF: bytes 4-7 'ftyp', bytes 8-11 one of the still-image brands.
  // Crucially, 'ftyp' + 'isom' / 'mp42' / 'qt  ' is MP4/QuickTime — those
  // must NOT be accepted as images.
  if (bytes[4] == 0x66 && // f
      bytes[5] == 0x74 && // t
      bytes[6] == 0x79 && // y
      bytes[7] == 0x70) { // p
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand == 'heic' ||
        brand == 'heix' ||
        brand == 'hevc' ||
        brand == 'hevx' ||
        brand == 'mif1' ||
        brand == 'msf1') {
      return ImageFormat.heic;
    }
  }

  return null;
}
