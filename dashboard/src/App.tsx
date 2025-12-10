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

interface Device {
  id: number
  hostname: string
  device_inventory_code?: string
  location_name: string
  host_location?: string
  city_town_village?: string
  laptop_model?: string
  compliance_status: string
  last_seen: string
  os_version: string
  latitude?: number
  longitude?: number
  serial_number?: string
}

function App() {
  const [selectedLocation, setSelectedLocation] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'dashboard' | 'websites' | 'software' | 'add-device'>('dashboard')
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null)

  return (
    <div className="app">
      <header className="app-header">
        <h1>VigyanShaala MDM Dashboard</h1>
        <div className="user-info">
          <span>Admin Mode</span>
        </div>
      </header>

      <div className="app-content">
        <aside className="nav-sidebar">
          <nav className="vertical-tabs">
            <button
              className={activeTab === 'dashboard' ? 'active' : ''}
              onClick={() => setActiveTab('dashboard')}
            >
              📊 Dashboard
            </button>
            <button
              className={activeTab === 'add-device' ? 'active' : ''}
              onClick={() => setActiveTab('add-device')}
            >
              ➕ Add/Edit Device
            </button>
            <button
              className={activeTab === 'websites' ? 'active' : ''}
              onClick={() => setActiveTab('websites')}
            >
              🌐 Website Blocklist
            </button>
            <button
              className={activeTab === 'software' ? 'active' : ''}
              onClick={() => setActiveTab('software')}
            >
              💻 Software Blocklist
            </button>
          </nav>
        </aside>

        <div className="content-wrapper">
          <aside className="sidebar">
            <LocationFilter 
              selectedLocation={selectedLocation}
              onLocationChange={setSelectedLocation}
            />
          </aside>

          <main className="main-content">
            {activeTab === 'dashboard' && (
              <>
                <section className="map-section">
                  <DeviceMap locationId={selectedLocation} />
                </section>

                <section className="inventory-section">
                  <AppInventory 
                    locationId={selectedLocation}
                    selectedDevice={selectedDevice}
                    onDeviceSelect={setSelectedDevice}
                    onCloseDetails={() => setSelectedDevice(null)}
                  />
                </section>

                {selectedDevice && (
                  <div style={{ marginTop: '1rem' }}></div>
                )}

                <section className="alerts-section">
                  <GeofenceAlerts locationId={selectedLocation} />
                </section>
              </>
            )}

            {activeTab === 'add-device' && (
              <section className="add-device-section">
                <AddDevice 
                  onDeviceAdded={() => {
                    setActiveTab('dashboard')
                    setSelectedDevice(null)
                  }}
                />
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
    </div>
  )
}

export default App
