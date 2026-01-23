# Web App Integration Guide: NativeAndroidBridge

This guide explains how the web application should communicate with the Flutter app via `NativeAndroidBridge` to enable "stay logged in" functionality.

## Overview

The Flutter app provides a JavaScript bridge (`NativeAndroidBridge`) that allows the web app to:
1. **Save authentication tokens** when user logs in
2. **Clear tokens** when user logs out
3. **Save FCM push notification tokens** for notifications

## Setup

The Flutter app automatically injects the `NativeAndroidBridge` API into the WebView. The web app can use it immediately without any setup.

## API Reference

### `NativeAndroidBridge.postMessage(message: string)`

Sends a JSON string message to the Flutter app.

**Parameters:**
- `message` (string): A JSON stringified object with the command and data

## Commands

### 1. Save Authentication Token (MANDATORY)

**When to call:** Immediately after successful login, when tokens are received from the backend.

**Format:**
```javascript
NativeAndroidBridge.postMessage(JSON.stringify({
  command: "saveToken",
  tokenType: "auth",
  accessToken: "<JWT_TOKEN>",
  refreshToken: "<REFRESH_TOKEN>" // Optional but recommended
}));
```

**Example:**
```javascript
// After successful login API call
async function handleLoginSuccess(loginResponse) {
  const { accessToken, refreshToken } = loginResponse.data;
  
  // Save tokens in your web app's storage (localStorage/cookies)
  localStorage.setItem('access_token', accessToken);
  if (refreshToken) {
    localStorage.setItem('refresh_token', refreshToken);
  }
  
  // CRITICAL: Send tokens to Flutter app
  if (window.NativeAndroidBridge) {
    NativeAndroidBridge.postMessage(JSON.stringify({
      command: "saveToken",
      tokenType: "auth",
      accessToken: accessToken,
      refreshToken: refreshToken || null
    }));
  }
}
```

**Important Notes:**
- ⚠️ **MANDATORY**: You MUST send the auth token with `tokenType: "auth"` for "stay logged in" to work
- The `accessToken` should be the JWT token received from your backend
- The `refreshToken` is optional but highly recommended
- Flutter will store these tokens securely and restore them on app restart

### 2. Save FCM Push Notification Token

**When to call:** When you receive or generate an FCM token for push notifications.

**Format:**
```javascript
NativeAndroidBridge.postMessage(JSON.stringify({
  command: "saveToken",
  tokenType: "fcm",
  token: "<FCM_TOKEN>"
}));
```

**Example:**
```javascript
// When FCM token is available
function sendFcmTokenToFlutter(fcmToken) {
  if (window.NativeAndroidBridge) {
    NativeAndroidBridge.postMessage(JSON.stringify({
      command: "saveToken",
      tokenType: "fcm",
      token: fcmToken
    }));
  }
}
```

### 3. Clear Tokens (Logout)

**When to call:** When user explicitly logs out.

**Format:**
```javascript
NativeAndroidBridge.postMessage(JSON.stringify({
  command: "clearToken"
}));
```

**Example:**
```javascript
function handleLogout() {
  // Clear tokens in your web app
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  
  // Notify Flutter app to clear tokens
  if (window.NativeAndroidBridge) {
    NativeAndroidBridge.postMessage(JSON.stringify({
      command: "clearToken"
    }));
  }
  
  // Redirect to login page
  window.location.href = '/login';
}
```

## Complete Integration Example

### React/Next.js Example

```javascript
// utils/flutterBridge.js
export const sendAuthTokenToFlutter = (accessToken, refreshToken = null) => {
  if (typeof window !== 'undefined' && window.NativeAndroidBridge) {
    try {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "saveToken",
        tokenType: "auth",
        accessToken: accessToken,
        refreshToken: refreshToken
      }));
      console.log('✅ Auth token sent to Flutter app');
    } catch (error) {
      console.error('❌ Error sending token to Flutter:', error);
    }
  }
};

export const sendFcmTokenToFlutter = (fcmToken) => {
  if (typeof window !== 'undefined' && window.NativeAndroidBridge) {
    try {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "saveToken",
        tokenType: "fcm",
        token: fcmToken
      }));
      console.log('✅ FCM token sent to Flutter app');
    } catch (error) {
      console.error('❌ Error sending FCM token to Flutter:', error);
    }
  }
};

export const clearFlutterTokens = () => {
  if (typeof window !== 'undefined' && window.NativeAndroidBridge) {
    try {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "clearToken"
      }));
      console.log('✅ Tokens cleared in Flutter app');
    } catch (error) {
      console.error('❌ Error clearing tokens in Flutter:', error);
    }
  }
};

// In your login handler (e.g., pages/login.js or components/LoginForm.jsx)
import { sendAuthTokenToFlutter } from '@/utils/flutterBridge';

async function handleLogin(credentials) {
  try {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials)
    });
    
    const data = await response.json();
    
    if (data.accessToken) {
      // Save in your web app's storage
      localStorage.setItem('access_token', data.accessToken);
      if (data.refreshToken) {
        localStorage.setItem('refresh_token', data.refreshToken);
      }
      
      // CRITICAL: Send to Flutter app
      sendAuthTokenToFlutter(data.accessToken, data.refreshToken);
      
      // Redirect to dashboard
      window.location.href = '/';
    }
  } catch (error) {
    console.error('Login failed:', error);
  }
}

// In your logout handler
import { clearFlutterTokens } from '@/utils/flutterBridge';

function handleLogout() {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  
  clearFlutterTokens();
  
  window.location.href = '/login';
}
```

### Vue.js Example

```javascript
// composables/useFlutterBridge.js
import { ref } from 'vue';

export function useFlutterBridge() {
  const sendAuthToken = (accessToken, refreshToken = null) => {
    if (window.NativeAndroidBridge) {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "saveToken",
        tokenType: "auth",
        accessToken: accessToken,
        refreshToken: refreshToken
      }));
    }
  };
  
  const sendFcmToken = (fcmToken) => {
    if (window.NativeAndroidBridge) {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "saveToken",
        tokenType: "fcm",
        token: fcmToken
      }));
    }
  };
  
  const clearTokens = () => {
    if (window.NativeAndroidBridge) {
      window.NativeAndroidBridge.postMessage(JSON.stringify({
        command: "clearToken"
      }));
    }
  };
  
  return {
    sendAuthToken,
    sendFcmToken,
    clearTokens
  };
}

// In your login component
import { useFlutterBridge } from '@/composables/useFlutterBridge';

const { sendAuthToken } = useFlutterBridge();

async function handleLogin() {
  const response = await login(credentials);
  if (response.accessToken) {
    localStorage.setItem('access_token', response.accessToken);
    sendAuthToken(response.accessToken, response.refreshToken);
    router.push('/');
  }
}
```

### Vanilla JavaScript Example

```javascript
// Check if running in Flutter WebView
const isFlutterApp = typeof window.NativeAndroidBridge !== 'undefined';

// After successful login
function onLoginSuccess(accessToken, refreshToken) {
  // Save in your storage
  localStorage.setItem('access_token', accessToken);
  if (refreshToken) {
    localStorage.setItem('refresh_token', refreshToken);
  }
  
  // Send to Flutter
  if (isFlutterApp) {
    window.NativeAndroidBridge.postMessage(JSON.stringify({
      command: "saveToken",
      tokenType: "auth",
      accessToken: accessToken,
      refreshToken: refreshToken
    }));
  }
}

// On logout
function onLogout() {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  
  if (isFlutterApp) {
    window.NativeAndroidBridge.postMessage(JSON.stringify({
      command: "clearToken"
    }));
  }
  
  window.location.href = '/login';
}
```

## Testing

1. **Test in Flutter app:**
   - Login in the web app
   - Check Flutter logs for: `💾 Saving auth token from web: ...`
   - Close and reopen the app
   - You should remain logged in (no login page)

2. **Test logout:**
   - Click logout in web app
   - Check Flutter logs for: `🗑️ Clearing tokens and session`
   - Close and reopen the app
   - You should see the login page

3. **Debug:**
   - Open browser console in WebView (if possible)
   - Check for `NativeAndroidBridge.postMessage API initialized`
   - Verify messages are being sent

## Troubleshooting

### Issue: User still sees login page after app restart

**Possible causes:**
1. ❌ Web app is not sending `saveToken` with `tokenType: "auth"` on login
2. ❌ Token is not being sent immediately after login success
3. ❌ Web app is using a different storage key than Flutter expects

**Solution:**
- Verify the web app calls `NativeAndroidBridge.postMessage` with `tokenType: "auth"` immediately after login
- Check Flutter logs to confirm token is being received
- Ensure the web app stores tokens in a key that Flutter can inject (see Flutter code for supported keys)

### Issue: Flutter logs show "Saving FCM token" but not "Saving auth token"

**Cause:** Web app is sending tokens without `tokenType: "auth"`, so Flutter treats them as FCM tokens.

**Solution:** Update web app to use explicit `tokenType: "auth"` format.

### Issue: Token injection works but web app doesn't auto-authenticate

**Possible causes:**
1. Web app doesn't read tokens from localStorage/sessionStorage on startup
2. Web app requires a specific event to trigger auth rehydration

**Solution:**
- Check what storage key your web app reads (Flutter injects into multiple keys)
- Verify your web app's auth initialization code reads from storage
- Consider listening for `storage` or `auth:updated` events that Flutter dispatches

## Security Notes

- Tokens are stored securely in Flutter using `FlutterSecureStorage`
- Tokens are only sent over the JavaScript bridge (not over network)
- The bridge only works within the Flutter WebView (not in regular browsers)
- Always validate tokens on the backend before trusting them

## Support

If you encounter issues:
1. Check Flutter debug logs for error messages
2. Verify the message format matches the examples above
3. Ensure `window.NativeAndroidBridge` exists before calling it
4. Test in the actual Flutter app (not just browser)

---

**Last Updated:** 2025-01-XX
**Flutter App Version:** 1.0.6+6
