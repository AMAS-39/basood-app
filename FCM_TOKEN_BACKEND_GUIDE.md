# FCM Token Backend Implementation Guide

## Overview
The Flutter app sends FCM (Firebase Cloud Messaging) tokens to the backend so the backend can send push notifications to specific users/devices.

## API Endpoint Details

### Endpoint
```
POST /api/User/FcmToken
```

### Request Headers
```
Authorization: Bearer {access_token}
Content-Type: application/json
```

### Request Body
```json
{
  "fcmToken": "dK3jF8...",  // The FCM token from Firebase
  "userId": "user-123"       // The user ID (from JWT token)
}
```

### Expected Response
- **Success**: `200 OK` (or any 2xx status)
- **Error**: `400 Bad Request`, `401 Unauthorized`, `500 Internal Server Error`, etc.

---

## What the Backend Needs to Do

### 1. **Store the FCM Token**
When the backend receives the FCM token, it should:

1. **Validate the request:**
   - Verify the JWT token in the `Authorization` header
   - Extract the `userId` from the JWT token (should match the `userId` in the body)
   - Validate that `fcmToken` is not empty

2. **Store the token in database:**
   - Create/update a record linking the `userId` to the `fcmToken`
   - **Important**: A user can have multiple devices, so store multiple tokens per user
   - Consider storing:
     - `userId` (string)
     - `fcmToken` (string, unique)
     - `deviceId` or `deviceInfo` (optional, to identify devices)
     - `createdAt` (timestamp)
     - `updatedAt` (timestamp)
     - `isActive` (boolean, to mark tokens as invalid)

### 2. **Database Schema Example**

```sql
CREATE TABLE user_fcm_tokens (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id VARCHAR(255) NOT NULL,
    fcm_token VARCHAR(500) NOT NULL UNIQUE,
    device_id VARCHAR(255) NULL,  -- Optional: to identify devices
    device_info TEXT NULL,       -- Optional: device name, OS, etc.
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_fcm_token (fcm_token)
);
```

### 3. **Handle Token Updates**
- If the same `fcmToken` is sent again, update the `updatedAt` timestamp
- If a new `fcmToken` is sent for the same user, add it as a new record (user can have multiple devices)
- If the user logs out, you can mark tokens as `is_active = false` or delete them

### 4. **Send Notifications to Users**
When you need to send a notification to a user:

1. **Query all active FCM tokens for that user:**
   ```sql
   SELECT fcm_token FROM user_fcm_tokens 
   WHERE user_id = ? AND is_active = TRUE
   ```

2. **Send notification using Firebase Admin SDK:**
   ```javascript
   // Example in Node.js
   const admin = require('firebase-admin');
   
   async function sendNotificationToUser(userId, title, body, data) {
     // Get all FCM tokens for the user
     const tokens = await db.query(
       'SELECT fcm_token FROM user_fcm_tokens WHERE user_id = ? AND is_active = TRUE'
     );
     
     if (tokens.length === 0) {
       console.log('No FCM tokens found for user:', userId);
       return;
     }
     
     const fcmTokens = tokens.map(t => t.fcm_token);
     
     // Send to all devices
     const message = {
       notification: {
         title: title,
         body: body,
       },
       data: data || {},
       tokens: fcmTokens,  // Send to multiple devices
     };
     
     try {
       const response = await admin.messaging().sendEachForMulticast(message);
       console.log('Successfully sent message:', response);
       
       // Handle invalid tokens
       if (response.failureCount > 0) {
         const failedTokens = [];
         response.responses.forEach((resp, idx) => {
           if (!resp.success) {
             failedTokens.push(fcmTokens[idx]);
           }
         });
         
         // Mark invalid tokens as inactive
         await db.query(
           'UPDATE user_fcm_tokens SET is_active = FALSE WHERE fcm_token IN (?)',
           [failedTokens]
         );
       }
     } catch (error) {
       console.error('Error sending message:', error);
     }
   }
   ```

### 5. **Handle Invalid Tokens**
FCM tokens can become invalid when:
- User uninstalls the app
- User clears app data
- Token expires (rare, but possible)

When sending notifications, if Firebase returns an error for a token:
- Mark that token as `is_active = false` in your database
- Don't try to send to that token again

---

## Backend Implementation Example (C# / ASP.NET Core)

```csharp
[HttpPost("FcmToken")]
[Authorize]  // Require authentication
public async Task<IActionResult> RegisterFcmToken([FromBody] RegisterFcmTokenRequest request)
{
    // Get userId from JWT token (from Authorization header)
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                 ?? User.FindFirst("sub")?.Value;
    
    if (string.IsNullOrEmpty(userId))
    {
        return Unauthorized("User ID not found in token");
    }
    
    // Validate request
    if (string.IsNullOrEmpty(request.FcmToken))
    {
        return BadRequest("FCM token is required");
    }
    
    // Verify userId matches (optional security check)
    if (!string.IsNullOrEmpty(request.UserId) && request.UserId != userId)
    {
        return BadRequest("User ID mismatch");
    }
    
    try
    {
        // Check if token already exists
        var existingToken = await _dbContext.UserFcmTokens
            .FirstOrDefaultAsync(t => t.FcmToken == request.FcmToken);
        
        if (existingToken != null)
        {
            // Update existing token
            existingToken.UserId = userId;
            existingToken.UpdatedAt = DateTime.UtcNow;
            existingToken.IsActive = true;
        }
        else
        {
            // Create new token record
            var newToken = new UserFcmToken
            {
                UserId = userId,
                FcmToken = request.FcmToken,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            
            _dbContext.UserFcmTokens.Add(newToken);
        }
        
        await _dbContext.SaveChangesAsync();
        
        return Ok(new { message = "FCM token registered successfully" });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { error = "Failed to register FCM token", details = ex.Message });
    }
}

public class RegisterFcmTokenRequest
{
    public string FcmToken { get; set; }
    public string UserId { get; set; }
}
```

---

## Backend Implementation Example (Node.js / Express)

```javascript
app.put('/api/User/FcmToken', authenticateToken, async (req, res) => {
  try {
    // Get userId from JWT token (from req.user after authentication middleware)
    const userId = req.user.id || req.user.sub;
    
    const { fcmToken, userId: bodyUserId } = req.body;
    
    // Validate
    if (!fcmToken) {
      return res.status(400).json({ error: 'FCM token is required' });
    }
    
    // Verify userId matches (optional security check)
    if (bodyUserId && bodyUserId !== userId) {
      return res.status(400).json({ error: 'User ID mismatch' });
    }
    
    // Check if token exists
    const existingToken = await db.query(
      'SELECT * FROM user_fcm_tokens WHERE fcm_token = ?',
      [fcmToken]
    );
    
    if (existingToken.length > 0) {
      // Update existing token
      await db.query(
        'UPDATE user_fcm_tokens SET user_id = ?, updated_at = NOW(), is_active = TRUE WHERE fcm_token = ?',
        [userId, fcmToken]
      );
    } else {
      // Insert new token
      await db.query(
        'INSERT INTO user_fcm_tokens (user_id, fcm_token, is_active, created_at, updated_at) VALUES (?, ?, TRUE, NOW(), NOW())',
        [userId, fcmToken]
      );
    }
    
    res.json({ message: 'FCM token registered successfully' });
  } catch (error) {
    console.error('Error registering FCM token:', error);
    res.status(500).json({ error: 'Failed to register FCM token' });
  }
});
```

---

## Important Notes

1. **Multiple Devices**: A user can have multiple FCM tokens (multiple devices). Store all of them and send notifications to all active tokens.

2. **Token Refresh**: The app will automatically send a new token when it refreshes. The backend should update the existing token or add it as a new one.

3. **Security**: 
   - Always verify the JWT token
   - The `userId` in the body should match the `userId` from the JWT token
   - Don't trust the `userId` from the body alone - extract it from the JWT

4. **Error Handling**: 
   - Return appropriate HTTP status codes
   - Log errors for debugging
   - Don't crash if token registration fails

5. **Cleanup**: Periodically clean up inactive tokens to keep the database clean.

---

## Testing

You can test the endpoint using curl:

```bash
curl -X POST http://192.168.1.248:7214/api/User/FcmToken \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fcmToken": "test-token-123",
    "userId": "user-123"
  }'
```

---

## Summary

**What the backend needs to do:**
1. ✅ Accept POST requests to `/api/User/FcmToken`
2. ✅ Verify JWT token from Authorization header
3. ✅ Extract userId from JWT token
4. ✅ Store/update FCM token in database (link userId → fcmToken)
5. ✅ Support multiple tokens per user (multiple devices)
6. ✅ When sending notifications, query all active tokens for a user
7. ✅ Use Firebase Admin SDK to send notifications to those tokens
8. ✅ Mark invalid tokens as inactive when Firebase reports them as invalid

The app will automatically send the FCM token:
- After login (mobile or WebView)
- When the token refreshes
- When the app starts (if user is already logged in)

