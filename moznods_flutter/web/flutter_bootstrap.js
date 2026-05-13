{{flutter_js}}
{{flutter_build_config}}

// CanvasKit optimization: pre-load before Flutter initializes
(function() {
  var link = document.createElement('link');
  link.rel = 'preload';
  link.as = 'script';
  link.href = 'https://cdn.flutter.dev/canvas/0.2024.0/canvaskit.js';
  link.crossorigin = 'anonymous';
  document.head.appendChild(link);
})();

_flutter.loader.load({
  config: {
    entryPointBaseUrl: '/static/',
    assetBase: '/static/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: "{{flutter_service_worker_version}}",
  },
});
