import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_planner/l10n/gen/app_localizations.dart';
import 'package:urban_farming_planner/model/project.dart';
import 'package:urban_farming_planner/ui/compass_dial.dart';
import 'package:urban_farming_planner/ui/space_wizard_page.dart';

void main() {
  late SpaceDraft? result;

  /// Mounts the wizard behind a button that pushes it, so the draft it pops
  /// with can be captured the way the editor captures it.
  Future<void> pumpWizard(
    WidgetTester tester, {
    Project? project,
    Locale locale = const Locale('id'),
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id'), Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<SpaceDraft>(
                    MaterialPageRoute(
                      builder: (_) =>
                          SpaceWizardPage(project: project ?? Project.empty()),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> goToStep(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('seeds its fields from the project it was given', (tester) async {
    await pumpWizard(tester);

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('field-width')))
          .controller
          ?.text,
      '2',
    );
    expect(find.text('Luas lantai 2,4 m²'), findsOneWidget);
  });

  testWidgets('the floor-area preview follows what is typed', (tester) async {
    await pumpWizard(tester);

    await tester.enterText(find.byKey(const Key('field-width')), '3');
    await tester.pump();

    expect(find.text('Luas lantai 3,6 m²'), findsOneWidget);
  });

  testWidgets('a size of zero is refused and sends the user back', (
    tester,
  ) async {
    await pumpWizard(tester);
    await tester.enterText(find.byKey(const Key('field-depth')), '0');
    await tester.pumpAndSettle();

    await goToStep(tester, 'Lokasi');
    await tester.tap(find.byKey(const Key('wizard-continue-3')));
    await tester.pumpAndSettle();

    expect(find.text('Isi dengan angka lebih dari 0'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('the compass dial sets the facing direction', (tester) async {
    await pumpWizard(tester);
    await goToStep(tester, 'Arah hadap');

    // Drag to the right edge of the dial: due east.
    final dial = tester.getRect(find.byType(CompassDial));
    await tester.tapAt(Offset(dial.right - 4, dial.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('90° T'), findsOneWidget);
  });

  testWidgets('picking a city sets the location', (tester) async {
    await pumpWizard(tester);
    await goToStep(tester, 'Lokasi');

    await tester.tap(find.byKey(const Key('city-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bandung').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wizard-continue-3')));
    await tester.pumpAndSettle();

    expect(result?.location?.label, 'Bandung');
    expect(result?.location?.latitude, closeTo(-6.9175, 1e-6));
  });

  testWidgets('saving returns the space the steps describe', (tester) async {
    await pumpWizard(tester);

    await tester.enterText(find.byKey(const Key('field-width')), '2.5');
    await tester.enterText(find.byKey(const Key('field-depth')), '1.5');
    await tester.enterText(find.byKey(const Key('field-height')), '2.4');
    await tester.pumpAndSettle();

    await goToStep(tester, 'Dinding & pagar');
    await tester.tap(find.byKey(const Key('barrier-east')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinding').last);
    await tester.pumpAndSettle();

    await goToStep(tester, 'Lokasi');
    await tester.tap(find.byKey(const Key('wizard-continue-3')));
    await tester.pumpAndSettle();

    final space = result!.space;
    expect(space.floorAreaM2, closeTo(3.75, 1e-9));
    expect(space.heightM, 2.4);
    expect(space.bounds.width, closeTo(2.5, 1e-9));
    expect(
      space.barriers.map((barrier) => barrier.id),
      containsAll(<String>['barrier-east']),
    );
    expect(space.barrierById('barrier-east')?.kind, BarrierKind.wall);
  });

  testWidgets('a barrier is never taller than the ceiling', (tester) async {
    await pumpWizard(tester);
    await tester.enterText(find.byKey(const Key('field-height')), '1.8');
    await tester.pumpAndSettle();

    await goToStep(tester, 'Lokasi');
    await tester.tap(find.byKey(const Key('wizard-continue-3')));
    await tester.pumpAndSettle();

    for (final barrier in result!.space.barriers) {
      expect(barrier.heightM, lessThanOrEqualTo(1.8));
    }
  });

  testWidgets('existing walls and railings come back as they were', (
    tester,
  ) async {
    await pumpWizard(tester);
    await goToStep(tester, 'Dinding & pagar');

    // Project.empty() puts a wall on the north side and a railing on the south.
    expect(find.text('Dinding'), findsWidgets);
    expect(find.text('Pagar'), findsWidgets);

    await goToStep(tester, 'Lokasi');
    await tester.tap(find.byKey(const Key('wizard-continue-3')));
    await tester.pumpAndSettle();

    expect(result!.space.barrierById('barrier-north')?.kind, BarrierKind.wall);
    expect(
      result!.space.barrierById('barrier-south')?.kind,
      BarrierKind.railing,
    );
  });
}
