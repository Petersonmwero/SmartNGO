import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/beneficiaries/beneficiary_repository.dart';
import 'package:smartngo/shared/widgets/kenya_location_picker.dart';

/// Serves the three /locations/kenya/ levels with canned data.
class LocationStub implements HttpClientAdapter {
  ResponseBody _json(Map<String, dynamic> body) =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final q = options.queryParameters;
    if (q.containsKey('counties')) {
      return _json({'status': 'success', 'data': ['Kisumu', 'Nairobi']});
    }
    if (q['county'] == 'Kisumu') {
      return _json({'status': 'success', 'data': ['Kisumu East', 'Seme']});
    }
    // Locations are scoped by (constituency, ward); match ward before the
    // bare-constituency (→ wards) case, mirroring the real API's precedence.
    if (q['ward'] == 'Nyalenda A' && q['constituency'] == 'Kisumu East') {
      return _json({'status': 'success', 'data': ['Nyalenda Loc A', 'Nyalenda Loc B']});
    }
    if (q['constituency'] == 'Kisumu East') {
      return _json({'status': 'success', 'data': ['Kolwa East', 'Nyalenda A']});
    }
    return _json({'status': 'success', 'data': []});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Map<String, String> lastEmitted;

  Widget buildPicker() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    dio.httpClientAdapter = LocationStub();
    final repo = BeneficiaryRepository(ApiClient(InMemoryTokenStore(), dio: dio));
    return Provider<BeneficiaryRepository>.value(
      value: repo,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KenyaLocationPicker(onChanged: (d) => lastEmitted = d),
          ),
        ),
      ),
    );
  }

  testWidgets('cascade: county loads constituencies, then wards, and emits',
      (tester) async {
    lastEmitted = const {};
    await tester.pumpWidget(buildPicker());
    await tester.pumpAndSettle();

    // Country is fixed to Kenya.
    expect(find.text('Kenya 🇰🇪'), findsOneWidget);

    // Constituency is disabled until a county is chosen.
    expect(find.text('Select county first'), findsOneWidget);

    // Pick a county.
    await tester.tap(find.byKey(const Key('county_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kisumu').last);
    await tester.pumpAndSettle();
    expect(lastEmitted['county'], 'Kisumu');

    // Pick a constituency (loaded from the stub).
    await tester.tap(find.byKey(const Key('constituency_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kisumu East').last);
    await tester.pumpAndSettle();
    expect(lastEmitted['constituency'], 'Kisumu East');

    // Pick a ward.
    await tester.tap(find.byKey(const Key('ward_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyalenda A').last);
    await tester.pumpAndSettle();
    expect(lastEmitted['ward'], 'Nyalenda A');

    // Pick a location (loaded for the ward) — the last dropdown level.
    await tester.ensureVisible(find.byKey(const Key('location_dropdown')));
    await tester.tap(find.byKey(const Key('location_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyalenda Loc A').last);
    await tester.pumpAndSettle();
    expect(lastEmitted['location'], 'Nyalenda Loc A');

    // No sub-location dropdown exists — village is free text.
    expect(find.byKey(const Key('sublocation_dropdown')), findsNothing);

    // Type a village; the full map is emitted.
    await tester.ensureVisible(find.byKey(const Key('village_field')));
    await tester.enterText(find.byKey(const Key('village_field')), 'Nyalenda');
    expect(lastEmitted, {
      'country': 'Kenya',
      'county': 'Kisumu',
      'constituency': 'Kisumu East',
      'ward': 'Nyalenda A',
      'location': 'Nyalenda Loc A',
      'village': 'Nyalenda',
    });
  });

  testWidgets('changing county resets all downstream levels', (tester) async {
    lastEmitted = const {};
    await tester.pumpWidget(buildPicker());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('county_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kisumu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('constituency_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kisumu East').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ward_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyalenda A').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('location_dropdown')));
    await tester.tap(find.byKey(const Key('location_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyalenda Loc A').last);
    await tester.pumpAndSettle();

    // Switch county → downstream selections reset.
    await tester.ensureVisible(find.byKey(const Key('county_dropdown')));
    await tester.tap(find.byKey(const Key('county_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nairobi').last);
    await tester.pumpAndSettle();

    expect(lastEmitted['county'], 'Nairobi');
    expect(lastEmitted['constituency'], '');
    expect(lastEmitted['ward'], '');
    expect(lastEmitted['location'], '');
  });
}
