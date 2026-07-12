import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static const _defaultProjectId = 'uljaorybezvnzedjveek';
  static const _defaultPublishableKey =
      'sb_publishable_Z-s82xrpFMClzA2moB404g_ityPEdXO';

  static bool _configured = false;

  static bool get configured => _configured;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    const projectId = String.fromEnvironment(
      'SUPABASE_PROJECT_ID',
      defaultValue: _defaultProjectId,
    );
    const publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: _defaultPublishableKey,
    );
    const explicitUrl = String.fromEnvironment('SUPABASE_URL');

    final url =
        explicitUrl.isNotEmpty ? explicitUrl : 'https://$projectId.supabase.co';

    if (publishableKey.isEmpty || projectId.isEmpty) {
      _configured = false;
      return;
    }

    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _configured = true;
  }
}
