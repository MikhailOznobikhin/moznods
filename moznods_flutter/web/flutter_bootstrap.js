{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    entryPointBaseUrl: '/static/',
    assetBase: '/static/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
