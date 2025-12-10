import { useState, useEffect } from 'react'
import { supabase } from '../supabase.config'
import LocationFilter from './components/LocationFilter'
import DeviceMap from './components/DeviceMap'
import AppInventory from './components/AppInventory'
import GeofenceAlerts from './components/GeofenceAlerts'
import WebsiteBlocklist from './components/WebsiteBlocklist'
import SoftwareBlocklist from './components/SoftwareBlocklist'
import AddDevice from './components/AddDevice'
import './App.css'

function App() {
  const [selectedLocation, setSelectedLocation] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'dashboard' | 'websites' | 'software' | 'add-device'>('dashboard')
  const [refreshKey, setRefreshKey] = useState(0)

  return (
    <div className="app">
      <header className="app-header">
        <h1>VigyanShaala MDM Dashboard</h1>
        <div className="user-info">
          <span>Admin Mode</span>
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
              className={activeTab === 'add-device' ? 'active' : ''}
              onClick={() => setActiveTab('add-device')}
            >
              Add Device
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
                <AppInventory 
                  locationId={selectedLocation}
                />
              </section>

              <section className="alerts-section">
                <GeofenceAlerts locationId={selectedLocation} />
              </section>
            </>
          )}

          {activeTab === 'add-device' && (
            <section className="add-device-section">
              <AddDevice onDeviceAdded={() => {
                setActiveTab('dashboard')
              }} />
            </section>
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

