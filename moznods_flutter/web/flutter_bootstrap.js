{{flutter_js}}
{{flutter_build_config}}

// AICODE-NOTE: Django serves the Flutter build under /static/ (STATICFILES_DIRS).
_flutter.loader.load({
  config: {
    entryPointBaseUrl: '/static/',
    assetBase: '/static/',
  },
});
