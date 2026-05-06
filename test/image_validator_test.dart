import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syanat/utils/image_validator.dart';

void main() {
  group('detectImageFormat', () {
    Uint8List pad(List<int> prefix, {int totalLen = 16}) {
      final out = List<int>.filled(totalLen, 0);
      for (var i = 0; i < prefix.length; i++) {
        out[i] = prefix[i];
      }
      return Uint8List.fromList(out);
    }

    test('JPEG detected by FF D8 FF prefix', () {
      expect(detectImageFormat(pad([0xFF, 0xD8, 0xFF, 0xE0])),
          ImageFormat.jpeg);
    });

    test('PNG detected by 89 50 4E 47 0D 0A 1A 0A', () {
      expect(
          detectImageFormat(
              pad([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
          ImageFormat.png);
    });

    test('WebP detected by RIFF + WEBP', () {
      expect(
          detectImageFormat(Uint8List.fromList([
            0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, //
            0x57, 0x45, 0x42, 0x50,
          ])),
          ImageFormat.webp);
    });

    test('HEIC detected by ftyp + heic brand', () {
      expect(
          detectImageFormat(Uint8List.fromList([
            0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, //
            0x68, 0x65, 0x69, 0x63,
          ])),
          ImageFormat.heic);
    });

    test('HEIF variant mif1 still detected as HEIC family', () {
      expect(
          detectImageFormat(Uint8List.fromList([
            0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, //
            0x6D, 0x69, 0x66, 0x31,
          ])),
          ImageFormat.heic);
    });

    test('MP4 (ftyp + isom) is rejected', () {
      expect(
          detectImageFormat(Uint8List.fromList([
            0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, //
            0x69, 0x73, 0x6F, 0x6D,
          ])),
          isNull,
          reason: 'MP4 video with ftyp+isom must not pass the image gate.');
    });

    test('QuickTime MOV (ftyp + qt  ) is rejected', () {
      expect(
          detectImageFormat(Uint8List.fromList([
            0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, //
            0x71, 0x74, 0x20, 0x20,
          ])),
          isNull);
    });

    test('all-zero bytes → null', () {
      expect(detectImageFormat(pad([])), isNull);
    });

    test('fewer than 12 bytes → null even with a JPEG prefix', () {
      expect(detectImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
          isNull);
    });
  });
}
