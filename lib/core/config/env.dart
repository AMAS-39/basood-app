class Env {
  // Backend API URL (port 7214) - for API requests
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hana-basod-ordering.azurewebsites.net',
  );
  // Frontend Web URL (port 5173) - for WebView screens
  static const webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://basood-post.vercel.app',
  );
}

//https://hana-basod-ordering.azurewebsites.net
//https://basood-post.vercel.app
