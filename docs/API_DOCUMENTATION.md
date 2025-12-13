# Medical Imaging Suite - API Documentation

Comprehensive API documentation for Medical Imaging Suite.

## Overview

REST API using JSON for requests and responses.

### Base URL

```
https://api.medical-imaging-suite.com/v1
```

### API Version

Current version: v1.0.0

### Authentication

Include API key in request header:

```http
Authorization: Bearer YOUR_API_KEY
```

## Endpoints

### User Management

#### Get User Profile
```http
GET /user/profile
```

**Response:**
```json
{
  "id": "user_123",
  "username": "johndoe",
  "email": "john@example.com",
  "created_at": "2024-01-15T10:30:00Z"
}
```

#### Update User Profile
```http
PUT /user/profile
```

### Data Operations

#### List Items
```http
GET /items?page=1&limit=20
```

**Query Parameters:**
- `page` (integer): Page number (default: 1)
- `limit` (integer): Items per page (default: 20, max: 100)
- `sort` (string): Sort field
- `order` (string): Sort order (asc/desc)

#### Create Item
```http
POST /items
```

**Request Body:**
```json
{
  "name": "New Item",
  "description": "Item description",
  "category": "general"
}
```

#### Update Item
```http
PUT /items/:id
```

#### Delete Item
```http
DELETE /items/:id
```

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes

| Code | Status | Description |
|------|--------|-------------|
| UNAUTHORIZED | 401 | Invalid authentication |
| FORBIDDEN | 403 | Insufficient permissions |
| NOT_FOUND | 404 | Resource not found |
| VALIDATION_ERROR | 422 | Invalid request data |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests |
| INTERNAL_ERROR | 500 | Server error |

## Rate Limiting

- **Free Tier**: 100 requests/hour
- **Pro Tier**: 1,000 requests/hour
- **Enterprise**: Custom limits

Rate limit headers:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Code Examples

### Python

```python
import requests

API_KEY = "your_api_key"
BASE_URL = "https://api.medical-imaging-suite.com/v1"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Get user profile
response = requests.get(f"{BASE_URL}/user/profile", headers=headers)
user = response.json()
```

### JavaScript

```javascript
const API_KEY = 'your_api_key';
const BASE_URL = 'https://api.medical-imaging-suite.com/v1';

fetch(`${BASE_URL}/user/profile`, {
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(user => console.log(user));
```

## Support

For API support:
- Documentation: https://akaash-nigam.github.io/medical-imaging-suite/docs
- Email: api-support@medical-imaging-suite.com

---

Last updated: 2024-01-15
