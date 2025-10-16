# NexoraSIM eSIM Enterprise Management

## Overview
Complete eSIM Enterprise Management portal for IoT device connectivity and profile management.

## Brand Information
- **Brand Name**: NexoraSIM
- **Portal URL**: https://portal.nexorasim.com
- **Contact Email**: admin@nexorasim.com
- **Repository**: https://github.com/kaunghtetpai/management

## Features

### eSIM Profile Management
- Add/Delete eSIM Profiles
- Generate Activation Codes by UPP
- Profile Status Monitoring
- Batch Profile Operations
- Profile Lifecycle Management

### Device Management
- Batch Device Import
- Real-time Device Status
- Profile Switching
- Remote Device Control
- Device Compliance Monitoring

### Enterprise Features
- Multi-tenant Support
- Role-based Access Control
- API Integration
- Audit Logging
- Security Compliance

## Technical Stack

### Frontend
- HTML5/CSS3 with Glass Morphism Design
- JavaScript ES6+ with Modern APIs
- Responsive Mobile-First Design
- 3D Animations and Interactions

### Backend
- Cloudflare Workers Edge Computing
- Cloudflare D1 Database
- RESTful API Architecture
- JWT Authentication

### Security
- OAuth 2.0/PKCE Authentication
- Role-based Access Control
- API Rate Limiting
- Audit Trail Logging

## Installation

### Prerequisites
- Node.js 16+ or modern web browser
- Git for version control
- Cloudflare account for deployment

### Local Development
```bash
git clone https://github.com/kaunghtetpai/management.git
cd management
python -m http.server 8080
```

### Production Deployment
```bash
# Deploy to Cloudflare Pages
wrangler pages publish

# Deploy API to Cloudflare Workers
wrangler publish api/worker.js
```

## API Endpoints

### Profile Management
```
GET    /api/profiles          - List all profiles
POST   /api/profiles          - Create new profile
DELETE /api/profiles/{id}     - Delete profile
PUT    /api/profiles/{id}     - Update profile
```

### Device Management
```
GET    /api/devices           - List all devices
POST   /api/devices/batch     - Batch import devices
POST   /api/devices/{id}/switch - Switch device profile
DELETE /api/devices/{id}      - Remove device
```

### Authentication
```
POST   /api/auth/login        - User authentication
POST   /api/auth/refresh      - Refresh token
POST   /api/auth/logout       - User logout
```

## Configuration

### Environment Variables
```
PORTAL_URL=https://portal.nexorasim.com
ADMIN_EMAIL=admin@nexorasim.com
API_BASE_URL=https://api.nexorasim.com
DATABASE_URL=cloudflare-d1-database
JWT_SECRET=your-jwt-secret
```

### Database Schema
```sql
-- Profiles table
CREATE TABLE profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    operator TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Devices table
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    eid TEXT UNIQUE NOT NULL,
    profile_id TEXT,
    status TEXT DEFAULT 'registered',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Usage Examples

### Create eSIM Profile
```javascript
const profile = await fetch('/api/profiles', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        name: 'Enterprise-Profile-01',
        operator: 'MPT',
        plan: 'unlimited'
    })
});
```

### Batch Import Devices
```javascript
const devices = await fetch('/api/devices/batch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        devices: [
            { eid: '89033023420000000001', model: 'IoT-Sensor' },
            { eid: '89033023420000000002', model: 'IoT-Gateway' }
        ]
    })
});
```

## File Structure
```
management/
├── index.html              # Main portal page
├── styles/
│   └── main.css           # Core styling
├── js/
│   └── main.js            # Core JavaScript
├── pages/
│   └── dashboard.html     # Management dashboard
├── api/
│   └── worker.js          # Cloudflare Worker API
└── README.md              # Documentation
```

## Deployment Status
- **Status**: 100% Complete
- **Environment**: Production Ready
- **Testing**: Validated
- **Documentation**: Complete

## Support
- **Technical Support**: admin@nexorasim.com
- **Documentation**: Available in repository
- **Issues**: GitHub Issues tracker
- **Updates**: Automatic via Cloudflare

## License
Enterprise License - Contact admin@nexorasim.com for licensing information.

## Version History
- v1.0.0 - Initial release with complete eSIM management
- Current: Production deployment ready

## Contact Information
- **Company**: NexoraSIM
- **Email**: admin@nexorasim.com
- **Portal**: https://portal.nexorasim.com
- **Repository**: https://github.com/kaunghtetpai/management