'use server'

import { GeminiOAuthService } from '@/lib/gemini-oauth'
import { connection } from '@/services/db/crud'

// Map en memoria para almacenar las promesas de autenticación pendientes
const authPromises = new Map<string, Promise<void>>()

/**
 * Check if user is authenticated with Gemini OAuth
 */
export async function checkGeminiAuthStatus(): Promise<{ authenticated: boolean }> {
  try {
    const oauthService = new GeminiOAuthService()
    const isAuthenticated = await oauthService.isAuthenticated()
    
    return {
      authenticated: isAuthenticated
    }
  } catch (error: any) {
    return { authenticated: false }
  }
}

/**
 * Initiate Gemini OAuth login flow
 */
export async function startGeminiOAuthLogin(): Promise<{
  success: boolean
  authUrl?: string
  message?: string
  error?: string
}> {
  try {
    const oauthService = new GeminiOAuthService()
    
    // Check if already authenticated
    if (await oauthService.isAuthenticated()) {
      return {
        success: true,
        message: 'Already authenticated'
      }
    }
    
    // Get the auth URL and start the authentication flow
    const { authUrl, loginCompletePromise } = await oauthService.authWithWeb()
    
    // Store the promise in the map
    authPromises.set(authUrl, loginCompletePromise)
    
    // Clean up after 5 minutes
    setTimeout(() => {
      authPromises.delete(authUrl)
    }, 300000)
    
    return {
      success: true,
      authUrl,
      message: 'Open the URL in your browser to authenticate'
    }
  } catch (error: any) {
    return {
      success: false,
      error: error.message
    }
  }
}

/**
 * Clear Gemini OAuth credentials
 */
export async function clearGeminiOAuthCredentials(): Promise<{
  success: boolean
  message?: string
  error?: string
}> {
  try {
    const oauthService = new GeminiOAuthService()
    await oauthService.clearCachedCredentials()
    
    // También eliminar la configuración del proveedor de la base de datos
    connection.delete('Gemini CLI')
    
    return {
      success: true,
      message: 'Credentials cleared successfully'
    }
  } catch (error: any) {
    return {
      success: false,
      error: error.message
    }
  }
}