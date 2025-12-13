import { useState, useEffect } from 'react'
import { supabase } from '../supabase.config'
import DeviceMap from './components/DeviceMap'
import AppInventory from './components/AppInventory'
import GeofenceAlerts from './components/GeofenceAlerts'
import WebsiteBlocklist from './components/WebsiteBlocklist'
import SoftwareBlocklist from './components/SoftwareBlocklist'
import DeviceDownloads from './components/DeviceDownloads'
import AddDevice from './components/AddDevice'
import DeviceSearchFilter from './components/DeviceSearchFilter'
import DeviceControl from './components/DeviceControl'
import ChatSupport from './components/ChatSupport'
import './App.css'

interface Device {
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

interface DeviceFilters {
  searchText: string
  locationId: string | null
  city: string
}

function App() {
  const [activeTab, setActiveTab] = useState<'dashboard' | 'websites' | 'software' | 'downloads' | 'add-device' | 'device-control' | 'chat'>('dashboard')
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null)
  const [filters, setFilters] = useState<DeviceFilters>({
    searchText: '',
    locationId: null,
    city: ''
  })

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-left">
          <img 
            src="/logo.png" 
            alt="VigyanShaala Logo" 
            className="header-logo"
            onError={(e) => {
              // Hide logo if file doesn't exist
              e.currentTarget.style.display = 'none';
            }}
          />
          <h1>VigyanShaala MDM Dashboard</h1>
        </div>
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
            <button
              className={activeTab === 'downloads' ? 'active' : ''}
              onClick={() => setActiveTab('downloads')}
            >
              📥 Device Software Downloads
            </button>
            <button
              className={activeTab === 'device-control' ? 'active' : ''}
              onClick={() => setActiveTab('device-control')}
            >
              🎮 Device Control
            </button>
            <button
              className={activeTab === 'chat' ? 'active' : ''}
              onClick={() => setActiveTab('chat')}
            >
              💬 Live Chat
            </button>
          </nav>
        </aside>

        <main className="main-content">
          {activeTab === 'dashboard' && (
            <>
              <section className="inventory-section">
                <DeviceSearchFilter onFilterChange={setFilters} />
                <AppInventory 
                  locationId={filters.locationId}
                  searchText={filters.searchText}
                  cityFilter={filters.city}
                  selectedDevice={selectedDevice}
                  onDeviceSelect={setSelectedDevice}
                  onCloseDetails={() => setSelectedDevice(null)}
                />
              </section>

              {selectedDevice && (
                <div style={{ marginTop: '1rem' }}></div>
              )}

              <section className="alerts-section">
                <GeofenceAlerts locationId={filters.locationId} />
              </section>

              <section className="map-section">
                <DeviceMap locationId={filters.locationId} />
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

          {activeTab === 'downloads' && (
            <section className="downloads-section">
              <DeviceDownloads />
            </section>
          )}

          {activeTab === 'device-control' && (
            <section className="device-control-section">
              <DeviceControl selectedDevice={selectedDevice?.hostname || null} />
            </section>
          )}

          {activeTab === 'chat' && (
            <section className="chat-section">
              <ChatSupport />
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default App
