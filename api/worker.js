// NexoraSIM eSIM Enterprise Management API
export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const path = url.pathname;
        
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        };
        
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }
        
        try {
            if (path.startsWith('/api/profiles')) {
                return await handleProfiles(request, env, path);
            } else if (path.startsWith('/api/devices')) {
                return await handleDevices(request, env, path);
            } else if (path.startsWith('/api/auth')) {
                return await handleAuth(request, env, path);
            } else {
                return jsonResponse({ message: 'NexoraSIM eSIM Enterprise Management API' });
            }
        } catch (error) {
            return jsonResponse({ error: error.message }, 500);
        }
    }
};

async function handleProfiles(request, env, path) {
    const method = request.method;
    
    switch (method) {
        case 'GET':
            return jsonResponse({
                profiles: [
                    { id: '1', name: 'Enterprise-Profile-01', operator: 'MPT', status: 'active' },
                    { id: '2', name: 'Enterprise-Profile-02', operator: 'OOREDOO', status: 'active' }
                ]
            });
        case 'POST':
            const data = await request.json();
            return jsonResponse({
                id: generateId(),
                name: data.name,
                operator: data.operator,
                status: 'created'
            }, 201);
        default:
            return jsonResponse({ error: 'Method not allowed' }, 405);
    }
}

async function handleDevices(request, env, path) {
    const method = request.method;
    
    switch (method) {
        case 'GET':
            return jsonResponse({
                devices: [
                    { id: '1', eid: '89033023420000000001', status: 'active', profile: 'Enterprise-Profile-01' },
                    { id: '2', eid: '89033023420000000002', status: 'active', profile: 'Enterprise-Profile-02' }
                ]
            });
        case 'POST':
            if (path.includes('/batch')) {
                const data = await request.json();
                return jsonResponse({
                    imported: data.devices.length,
                    status: 'success'
                });
            }
            break;
        default:
            return jsonResponse({ error: 'Method not allowed' }, 405);
    }
}

async function handleAuth(request, env, path) {
    if (path.includes('/login')) {
        return jsonResponse({
            token: 'jwt-token-example',
            user: { email: 'admin@nexorasim.com' },
            expires: Date.now() + (24 * 60 * 60 * 1000)
        });
    }
    return jsonResponse({ error: 'Auth endpoint not found' }, 404);
}

function jsonResponse(data, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    });
}

function generateId() {
    return Math.random().toString(36).substr(2, 9);
}