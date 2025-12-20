class Env {
  // Backend API URL (port 7214) - for API requests
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '//http://192.168.1.248:7214');
  // Frontend Web URL (port 5173) - for WebView screens
  static const webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'http://192.168.1.248:5173');
}

//https://hana-basod-ordering.azurewebsites.net
//https://basood-order-test-2025-2026.netlify.app