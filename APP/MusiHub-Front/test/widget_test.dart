import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:musihub_front/core/formatters/date_formatters.dart';
import 'package:musihub_front/features/alerts/alerts_api.dart';
import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/notifications/notifications_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/search/search_api.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('MusiHub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Iniciar sesion'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Crear cuenta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.widgetWithText(OutlinedButton, 'Crear cuenta'), findsOneWidget);
  });

  test('builds opportunity filter query params', () {
    const filters = OpportunityFilters(
      typeId: 1,
      city: ' Granada ',
      province: '',
      instrumentId: 2,
      styleId: 1,
      dateFrom: '2026-06-01',
      dateTo: '2026-06-30',
      minPrice: 10,
      maxPrice: 30,
    );

    expect(filters.toQueryParameters(), {
      'type_id': '1',
      'city': 'Granada',
      'instrument_id': '2',
      'style_id': '1',
      'date_from': '2026-06-01',
      'date_to': '2026-06-30',
      'min_price': '10',
      'max_price': '30',
    });
  });

  test('formats local date labels', () {
    expect(formatLocalDateLabel('2026-06-01T10:05:00'), '01/06/2026');
    expect(formatLocalDateLabel('not-a-date'), 'not-a-date');
  });

  test('formats local date time labels', () {
    expect(formatLocalDateTimeLabel('2026-06-01T10:05:00'), '01/06/2026 10:05');
    expect(formatLocalDateTimeLabel('not-a-date'), 'not-a-date');
  });

  test('formats opportunity date labels', () {
    expect(opportunityShortDateLabel('2026-04-15'), '15/04');
    expect(opportunityLongDateLabel('2026-04-15'), '15 Abr 2026');
    expect(opportunityLongDateLabel('2026-04-15T20:00:00Z'), '15 Abr 2026');
    expect(opportunityLongDateLabel('not-a-date'), 'not-a-date');
  });

  test('builds opportunity text search query param', () {
    const filters = OpportunityFilters(query: ' guitarra ');

    expect(filters.toQueryParameters(), {'q': 'guitarra'});
  });

  test('parses opportunity author user', () {
    final opportunity = Opportunity.fromJson({
      'id': 1,
      'type': {'id': 1, 'code': 'clases', 'name': 'Clases'},
      'author_user_id': 7,
      'author_user': {'id': 7, 'full_name': 'Usuario Test'},
      'author_band': null,
      'title': 'Clases de guitarra',
      'description': 'Clases para principiantes',
      'city': 'Granada',
      'province': 'Granada',
      'event_date': null,
      'price_amount': null,
      'contact_method': 'whatsapp',
      'contact_value': null,
      'status': 'active',
      'created_at': '2026-05-25T10:00:00Z',
      'updated_at': '2026-05-25T10:00:00Z',
      'expires_at': null,
      'instruments': [],
      'styles': [],
    });

    expect(opportunity.authorUser?.id, 7);
    expect(opportunity.authorUser?.fullName, 'Usuario Test');
  });

  test('parses public profile without private contact data', () {
    final profile = PublicProfile.fromJson({
      'user': {'id': 7, 'full_name': 'Usuario Test'},
      'profile': {
        'id': 3,
        'city': 'Granada',
        'province': 'Granada',
        'bio': 'Bio publica',
        'photo_url': null,
        'website_url': 'https://instagram.com/musihub',
        'instruments': [
          {'id': 2, 'name': 'Guitarra', 'is_primary': true},
        ],
        'styles': [
          {'id': 1, 'name': 'Rock'},
        ],
      },
      'bands': [
        {
          'id': 1,
          'name': 'Nombre Banda',
          'role_in_band': 'guitarra',
          'city': 'Granada',
          'province': 'Granada',
          'photo_url': null,
          'styles': [],
        },
      ],
    });

    expect(profile.user.fullName, 'Usuario Test');
    expect(profile.profile?.websiteUrl, 'https://instagram.com/musihub');
    expect(profile.profile?.contactEmail, isNull);
    expect(profile.profile?.contactPhone, isNull);
    expect(profile.bands.single.name, 'Nombre Banda');
  });

  test('parses global search profile and band results', () {
    final profile = ProfileSearchResult.fromJson({
      'user': {'id': 7, 'full_name': 'Usuario Test'},
      'profile_id': 3,
      'city': 'Granada',
      'province': 'Granada',
      'bio': 'Bio publica',
      'photo_url': null,
      'website_url': 'https://musihub.app',
      'instruments': [
        {'id': 2, 'name': 'Guitarra'},
      ],
      'styles': [
        {'id': 1, 'name': 'Rock'},
      ],
    });
    final band = BandSearchResult.fromJson({
      'id': 1,
      'name': 'Nombre Banda',
      'bio': 'Bio de banda',
      'city': 'Granada',
      'province': 'Granada',
      'photo_url': null,
      'styles': [
        {'id': 1, 'name': 'Rock'},
      ],
    });

    expect(profile.user.fullName, 'Usuario Test');
    expect(profile.websiteUrl, 'https://musihub.app');
    expect(profile.instruments.single.name, 'Guitarra');
    expect(band.name, 'Nombre Banda');
    expect(band.styles.single.name, 'Rock');
  });

  test('builds profile payload with website url', () {
    const request = ProfileSaveRequest(
      city: 'Granada',
      province: 'Granada',
      bio: 'Bio publica',
      photoUrl: null,
      websiteUrl: 'https://instagram.com/musihub',
      contactEmail: null,
      contactPhone: null,
      instrumentIds: [2],
      primaryInstrumentId: 2,
      styleIds: [1],
    );

    expect(request.toJson(), {
      'city': 'Granada',
      'province': 'Granada',
      'bio': 'Bio publica',
      'photo_url': null,
      'website_url': 'https://instagram.com/musihub',
      'contact_email': null,
      'contact_phone': null,
      'instrument_ids': [2],
      'primary_instrument_id': 2,
      'style_ids': [1],
    });
  });

  test('parses notifications response', () {
    final response = NotificationsResponse.fromJson({
      'unread_count': 1,
      'items': [
        {
          'id': 1,
          'type': 'alert_match',
          'title': 'Nueva oportunidad en MusiHub',
          'body': 'Clases de guitarra',
          'created_at': '2026-06-01T10:00:00Z',
          'read_at': null,
          'data': {'opportunity_id': 34},
        },
        {
          'id': 2,
          'type': 'contact_request_accepted',
          'title': 'Solicitud aceptada',
          'body': 'Ya puedes ver el contacto del anuncio',
          'created_at': '2026-06-01T11:00:00Z',
          'read_at': '2026-06-01T11:05:00Z',
          'data': null,
        },
      ],
    });

    expect(response.unreadCount, 1);
    expect(response.items.first.isUnread, isTrue);
    expect(response.items.first.data?['opportunity_id'], 34);
    expect(response.items.last.isUnread, isFalse);
  });

  test('parses notification read response', () {
    final response = NotificationReadResponse.fromJson({
      'id': 1,
      'read_at': '2026-06-01T10:05:00Z',
    });

    expect(response.id, 1);
    expect(response.readAt, '2026-06-01T10:05:00Z');
  });

  test('builds band create payload', () {
    const request = BandSaveRequest(
      name: 'Green Music',
      bio: 'Banda de rock',
      city: 'Granada',
      province: 'Granada',
      photoUrl: null,
      roleInBand: 'Guitarra, Voz',
      isVisibleInProfile: true,
      styleIds: [1, 4],
    );

    expect(request.toJson(), {
      'name': 'Green Music',
      'bio': 'Banda de rock',
      'city': 'Granada',
      'province': 'Granada',
      'photo_url': null,
      'role_in_band': 'Guitarra, Voz',
      'is_visible_in_profile': true,
      'style_ids': [1, 4],
    });
  });

  test('builds band update payload', () {
    const request = BandUpdateRequest(
      name: 'Green Music',
      bio: null,
      city: 'Granada',
      province: 'Granada',
      photoUrl: null,
      styleIds: [1],
    );

    expect(request.toJson(), {
      'name': 'Green Music',
      'bio': null,
      'city': 'Granada',
      'province': 'Granada',
      'photo_url': null,
      'style_ids': [1],
    });
  });

  test('parses band photo upload response', () {
    final response = BandPhotoUploadResponse.fromJson({
      'photo_url': '/uploads/bands/band_3_test.jpg',
    });

    expect(response.photoUrl, '/uploads/bands/band_3_test.jpg');
  });

  test('builds band member create payload', () {
    const request = BandMemberSaveRequest(
      userId: 8,
      roleInBand: 'Bateria, Voz',
      isVisibleInProfile: true,
    );

    expect(request.toJson(), {
      'user_id': 8,
      'role_in_band': 'Bateria, Voz',
      'is_visible_in_profile': true,
    });
  });

  test('builds alert preferences payload', () {
    const request = AlertPreferencesSaveRequest(
      frequency: 'immediate',
      preferredCity: 'Granada',
      preferredProvince: null,
      notificationsEnabled: true,
      opportunityTypeIds: [1, 2],
      instrumentIds: [2],
      styleIds: [1],
    );

    expect(request.toJson(), {
      'frequency': 'immediate',
      'preferred_city': 'Granada',
      'preferred_province': null,
      'notifications_enabled': true,
      'opportunity_type_ids': [1, 2],
      'instrument_ids': [2],
      'style_ids': [1],
    });
  });
}
