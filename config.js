(() => {
  'use strict';

  window.GTIConfig = Object.freeze({
    supabaseUrl: 'https://nfuzjklrluhninqybfhx.supabase.co',
    supabasePublishableKey: 'sb_publishable_3XDfV-YAelqb9OE46m_2tA_4gDGHaSk',
    termsVersion: '1.2',
    sessionStorageKey: 'gti_missions_session_v1',
    avatarBucket: 'gti-missions-avatars',
    checkinBucket: 'gti-missions-checkins',
    maxAvatarBytes: 5 * 1024 * 1024,
    supportedImageTypes: Object.freeze(['image/jpeg', 'image/png', 'image/webp']),
  });
})();
