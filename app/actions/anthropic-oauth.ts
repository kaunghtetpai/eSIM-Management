'use server'

import { getOAuthConfig } from '@/lib/oauth-config-loader'
import { connection, keyValue } from '@/services/db/crud'
import crypto from 'crypto'

// OAuth configuration will be loaded dynamically
let oauthConfig: Awaited<ReturnType<typeof getOAuthConfig>>['anthropic'] | null = null

async function ensureOAuthConfig() {
  if (!oauthConfig) {
    const configs = await getOAuthConfig()
    oauthConfig = configs.anthropic
  }
  return oauthConfig
}

interface PKCE {
  verifier: string
  challenge: string
}

interface TokenResponse {
  access_token: string
  refresh_token?: string
  expires_in: number
}

interface ApiKeyResponse {
  raw_key: string
  id: string
  name: string
  created_at: string
  partial_key_hint: string
  status: string
}

function generatePKCE(): PKCE {
  const verifier = crypto.randomBytes(32).toString('base64url')
  const challenge = crypto.createHash('sha256').update(verifier).digest('base64url')
  return { verifier, challenge }
}

function generateState(): string {
  return crypto.randomBytes(32).toString('base64url')
}

export async function startAnthropicOAuth() {
  try {
    const config = await ensureOAuthConfig()
    const pkce = generatePKCE()
    const state = generateState()

    const authUrl = new URL(config.authorizeUrl)
    authUrl.searchParams.set('code', 'true')
    authUrl.searchParams.set('client_id', config.clientId)
    authUrl.searchParams.set('response_type', 'code')
    authUrl.searchParams.set('redirect_uri', config.redirectUri)
    authUrl.searchParams.set('scope', config.scopes.join(' '))
    authUrl.searchParams.set('state', state)
    authUrl.searchParams.set('code_challenge', pkce.challenge)
    authUrl.searchParams.set('code_challenge_method', 'S256')

    // Store the PKCE verifier and state in keyValue store
    const oauthData = {
      verifier: pkce.verifier,
      state,
      timestamp: Date.now()
    }
    keyValue.upsert({
      key: 'anthropic-oauth-data',
      value: JSON.stringify(oauthData)
    })

    return {
      success: true,
      authUrl: authUrl.toString(),
      verifier: pkce.verifier,
      state
    }
  } catch (error) {
    console.error('Error starting OAuth flow:', error)
    return {
      success: false,
      error: 'Failed to start OAuth flow'
    }
  }
}

export async function completeAnthropicOAuth(authCode: string) {
  if (!authCode) {
    return {
      success: false,
      error: 'Missing authorization code'
    }
  }

  try {
    const config = await ensureOAuthConfig()
    // Parse the code - it might come in format "code#state" from Anthropic's callback page
    const [code, receivedState] = authCode.includes('#') ? authCode.split('#') : [authCode, null]

    // Get stored OAuth data from keyValue
    const storedData = keyValue.get('anthropic-oauth-data')
    if (!storedData) {
      return {
        success: false,
        error: 'OAuth session not found. Please start the authentication process again.'
      }
    }

    let oauthData: { verifier: string; state: string; timestamp: number }
    try {
      oauthData = JSON.parse(storedData)
    } catch (e) {
      return {
        success: false,
        error: 'Invalid OAuth session data'
      }
    }

    // Check if OAuth session is expired (older than 10 minutes)
    if (Date.now() - oauthData.timestamp > 600000) {
      keyValue.delete('anthropic-oauth-data')
      return {
        success: false,
        error: 'OAuth session expired. Please try again.'
      }
    }

    // Exchange code for tokens - using JSON format like Claude Code
    const tokenPayload = {
      grant_type: 'authorization_code',
      code,
      redirect_uri: config.redirectUri,
      client_id: config.clientId,
      code_verifier: oauthData.verifier,
      state: receivedState || oauthData.state
    }

    const tokenResponse = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(tokenPayload)
    })

    if (!tokenResponse.ok) {
      const error = await tokenResponse.text()
      throw new Error(`Token exchange failed: ${error}`)
    }

    const tokenData = (await tokenResponse.json()) as TokenResponse

    // Create API key using access token
    const apiKeyResponse = await fetch(config.apiKeyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenData.access_token}`
      },
      body: JSON.stringify({}) // Empty payload - server generates everything
    })

    if (!apiKeyResponse.ok) {
      const error = await apiKeyResponse.text()
      throw new Error(`API key creation failed: ${error}`)
    }

    const apiKeyData = (await apiKeyResponse.json()) as ApiKeyResponse

    // Save the API key
    connection.upsert({
      provider: 'Anthropic',
      apikey: apiKeyData.raw_key,
      // Store additional metadata for reference
      google_Oauth: JSON.stringify({
        type: 'oauth_generated',
        key_id: apiKeyData.id,
        key_name: apiKeyData.name,
        created_at: apiKeyData.created_at,
        partial_key_hint: apiKeyData.partial_key_hint
      })
    })

    // Clean up OAuth data from keyValue
    keyValue.delete('anthropic-oauth-data')

    return {
      success: true,
      apiKey: apiKeyData.raw_key,
      keyName: apiKeyData.name
    }
  } catch (error: any) {
    console.error('Error in OAuth callback:', error)
    // Clean up on error
    keyValue.delete('anthropic-oauth-data')
    return {
      success: false,
      error: error.message || 'Failed to complete OAuth flow'
    }
  }
}

export async function checkAnthropicAuthStatus() {
  try {
    const providerConnection = connection.getByProvider('Anthropic')

    if (!providerConnection?.apikey) {
      return { authenticated: false }
    }

    // Check if this is an OAuth-generated key by looking at metadata
    let metadata = null
    if (providerConnection.google_Oauth) {
      try {
        metadata = JSON.parse(providerConnection.google_Oauth)
      } catch {}
    }

    return {
      authenticated: true,
      isOAuthGenerated: metadata?.type === 'oauth_generated',
      keyName: metadata?.key_name,
      keyHint: metadata?.partial_key_hint
    }
  } catch (error) {
    console.error('Error checking auth status:', error)
    return { authenticated: false }
  }
}

export async function logoutAnthropicOAuth() {
  try {
    const providerConnection = connection.getByProvider('Anthropic')

    // Only clear OAuth-generated keys
    if (providerConnection?.google_Oauth) {
      try {
        const metadata = JSON.parse(providerConnection.google_Oauth)
        if (metadata.type === 'oauth_generated') {
          // Clear the API key but keep the provider entry
          connection.upsert({
            provider: 'Anthropic',
            apikey: '',
            google_Oauth: ''
          })
        }
      } catch {}
    }

    return { success: true }
  } catch (error) {
    console.error('Error during logout:', error)
    return {
      success: false,
      error: 'Failed to logout'
    }
  }
}
