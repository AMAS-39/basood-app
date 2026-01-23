# Basood Post - Flutter Mobile App

Flutter mobile application for Basood Post delivery management system.

## Web App Integration

**⚠️ IMPORTANT FOR WEB DEVELOPERS:**

The web application must send authentication tokens to the Flutter app for "stay logged in" functionality to work.

**See [WEB_INTEGRATION_GUIDE.md](./WEB_INTEGRATION_GUIDE.md) for complete integration instructions.**

### Quick Start for Web Team

After successful login, the web app MUST call:

```javascript
NativeAndroidBridge.postMessage(JSON.stringify({
  command: "saveToken",
  tokenType: "auth",
  accessToken: "<JWT_TOKEN>",
  refreshToken: "<REFRESH_TOKEN>" // Optional
}));
```

This is **mandatory** - without it, users will be logged out when they close and reopen the app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
