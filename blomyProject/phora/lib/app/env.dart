enum AppEnvironment { stage, prod }

const kPreviewOnboarding = false;
const kAppEnvironmentName = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'stage',
);
const kAppEnvironment =
    kAppEnvironmentName == 'prod' ? AppEnvironment.prod : AppEnvironment.stage;
const kDefaultApiBaseUrl =
    kAppEnvironment == AppEnvironment.prod
        ? 'https://prod.api.vyla.health/api/v1'
        : 'https://stage.api.vyla.health/api/v1';
const kVylaApiBaseUrl = String.fromEnvironment(
  'VYLA_API_BASE_URL',
  defaultValue: '',
);
const kBloomyApiBaseUrl = String.fromEnvironment(
  'BLOOMY_API_BASE_URL',
  defaultValue: '',
);
const kConfiguredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);
const kApiBaseUrl =
    kConfiguredApiBaseUrl != ''
        ? kConfiguredApiBaseUrl
        : kVylaApiBaseUrl != ''
        ? kVylaApiBaseUrl
        : kDefaultApiBaseUrl;
const kGoogleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue:
      '738931349922-c5cfs8p3mr0r1u8gcrlchl2qp0vcqbln.apps.googleusercontent.com',
);
const kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '738931349922-p1fijrg81cf8duenffa85k0cnra55ckq.apps.googleusercontent.com',
);
const kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);
const kSubscriptionStatusPath = String.fromEnvironment(
  'SUBSCRIPTION_STATUS_PATH',
  defaultValue: '/api/v1/billing/subscription',
);
