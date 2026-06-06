import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phora/app/app.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/auth/token_store.dart';

class _FakeTokenStore implements TokenStore {
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _authMode;
  String? _email;

  @override
  Future<void> clear() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _authMode = null;
    _email = null;
  }

  @override
  Future<String?> readAccessToken() async => _token;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<String?> readAuthMode() async => _authMode;

  @override
  Future<String?> readEmail() async => _email;

  @override
  Future<String?> readUserId() async => _userId;

  @override
  Future<void> writeAccessToken(String token) async {
    _token = token;
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<void> writeAuthMode(String mode) async {
    _authMode = mode;
  }

  @override
  Future<void> writeEmail(String email) async {
    _email = email;
  }

  @override
  Future<void> writeUserId(String userId) async {
    _userId = userId;
  }
}

void main() {
  testWidgets('renders the Phora bootstrap shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(_FakeTokenStore())],
        child: const PhoraApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
