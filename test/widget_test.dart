import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/user_home_screen.dart';

void main() {
  group('customer home service composition', () {
    test('pins the exact five homepage services in the requested order', () {
      final pinned = buildPinnedHomeServices(homeServiceCatalog);

      expect(
        pinned.map((service) => service.key).toList(),
        equals([
          'ac',
          'plumbing',
          'electricity',
          'large_appliances',
          'carpentry',
        ]),
      );

      expect(
        pinned.map((service) => service.label(true)).toList(),
        equals([
          'Air Conditioning',
          'Plumbing',
          'Electricity',
          'Large Appliances',
          'Carpentry',
        ]),
      );
    });

    test('More excludes the five pinned services and keeps the remaining keys', () {
      final remaining = buildRemainingHomeServices(homeServiceCatalog);

      expect(
        remaining.map((service) => service.key).toList(),
        equals([
          'security_intercom',
          'small_appliances',
          'pest_control',
          'aluminum',
          'finishing',
        ]),
      );

      for (final key in prioritizedHomeServiceKeys) {
        expect(
          remaining.any((service) => service.key == key),
          isFalse,
        );
      }
    });

    test('selection metadata keeps the original stable service keys and route labels', () {
      final electricity = buildPinnedHomeServices(homeServiceCatalog)
          .firstWhere((service) => service.key == 'electricity');
      final finishing = buildRemainingHomeServices(homeServiceCatalog)
          .firstWhere((service) => service.key == 'finishing');

      expect(electricity.key, 'electricity');
      expect(electricity.routeLabelEn, 'Electrical');
      expect(electricity.routeLabelAr, 'كهرباء');
      expect(electricity.label(true), 'Electricity');

      expect(finishing.key, 'finishing');
      expect(finishing.routeLabelEn, 'Finishing');
      expect(finishing.routeLabelAr, 'تشطيبات');
    });
  });
}
