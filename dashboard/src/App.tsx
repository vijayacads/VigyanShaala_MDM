import { useState, useEffect } from 'react'
import { supabase } from '../supabase.config'
import LocationFilter from './components/LocationFilter'
import DeviceMap from './components/DeviceMap'
import AppInventory from './components/AppInventory'
import GeofenceAlerts from './components/GeofenceAlerts'
import WebsiteBlocklist from './components/WebsiteBlocklist'
import SoftwareBlocklist from './components/SoftwareBlocklist'
import './App.css'

function App() {
  const [selectedLocation, setSelectedLocation] = useState<string | null>(null)
  const [user, setUser] = useState<any>(null)
  const [activeTab, setActiveTab] = useState<'dashboard' | 'websites' | 'software'>('dashboard')

  useEffect(() => {
    // Check auth status
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (!user) {
    return (
      <div className="login-container">
        <h1>MDM Dashboard</h1>
        <p>Please sign in to continue</p>
        <button onClick={() => supabase.auth.signInWithOAuth({ provider: 'google' })}>
          Sign in with Google
        </button>
      </div>
    )
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>VigyanShaala MDM Dashboard</h1>
        <div className="user-info">
          <span>{user.email}</span>
          <button onClick={() => supabase.auth.signOut()}>Sign Out</button>
        </div>
      </header>

      <div className="app-content">
        <aside className="sidebar">
          <LocationFilter 
            selectedLocation={selectedLocation}
            onLocationChange={setSelectedLocation}
          />
        </aside>

        <main className="main-content">
          <div className="tabs">
            <button
              className={activeTab === 'dashboard' ? 'active' : ''}
              onClick={() => setActiveTab('dashboard')}
            >
              Dashboard
            </button>
            <button
              className={activeTab === 'websites' ? 'active' : ''}
              onClick={() => setActiveTab('websites')}
            >
              Website Blocklist
            </button>
            <button
              className={activeTab === 'software' ? 'active' : ''}
              onClick={() => setActiveTab('software')}
            >
              Software Blocklist
            </button>
          </div>

          {activeTab === 'dashboard' && (
            <>
              <section className="map-section">
                <DeviceMap locationId={selectedLocation} />
              </section>

              <section className="inventory-section">
                <AppInventory locationId={selectedLocation} />
              </section>

              <section className="alerts-section">
                <GeofenceAlerts locationId={selectedLocation} />
              </section>
            </>
          )}

          {activeTab === 'websites' && (
            <section className="blocklist-section">
              <WebsiteBlocklist />
            </section>
          )}

          {activeTab === 'software' && (
            <section className="blocklist-section">
              <SoftwareBlocklist />
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default App

