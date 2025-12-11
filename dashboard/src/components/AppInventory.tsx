import { useState, useEffect, useMemo } from 'react'
import { AgGridReact } from 'ag-grid-react'
import { ColDef, ICellRendererParams } from 'ag-grid-community'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'
import { supabase } from '../../supabase.config'
import './AppInventory.css'

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

interface AppInventoryProps {
  locationId: string | null
  searchText?: string
  cityFilter?: string
  onDeviceSelect?: (device: Device) => void
  selectedDevice: Device | null
  onCloseDetails: () => void
}

// Status cell renderer component
const StatusRenderer = (params: ICellRendererParams) => {
  const status = params.value
  const color = status === 'compliant' ? '#10b981' : status === 'non_compliant' ? '#ef4444' : '#6b7280'
  return <span style={{ color, fontWeight: 'bold' }}>{status.toUpperCase().replace('_', ' ')}</span>
}

export default function AppInventory({ locationId, searchText = '', cityFilter = '', onDeviceSelect, selectedDevice, onCloseDetails }: AppInventoryProps) {
  const [devices, setDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(true)
  
  // Load saved column state from localStorage
  const getSavedColumnState = () => {
    try {
      const saved = localStorage.getItem('deviceInventoryColumns')
      if (saved) return JSON.parse(saved)
    } catch (e) {
      console.error('Error loading column state:', e)
    }
    return null
  }
  
  // Save column state to localStorage
  const saveColumnState = (state: any) => {
    try {
      localStorage.setItem('deviceInventoryColumns', JSON.stringify(state))
    } catch (e) {
      console.error('Error saving column state:', e)
    }
  }

  useEffect(() => {
    fetchDevices()
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('devices-inventory')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'devices' },
        () => fetchDevices()
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [locationId])

  async function fetchDevices() {
    try {
      setLoading(true)
      
      let query = supabase
        .from('devices')
        .select(`
          hostname,
          device_inventory_code,
          compliance_status,
          last_seen,
          os_version,
          location_id,
          host_location,
          city_town_village,
          laptop_model,
          latitude,
          longitude,
          serial_number,
          locations(name)
        `)

      if (locationId) {
        query = query.eq('location_id', locationId)
      }

      const { data, error } = await query

      if (error) throw error

      const formattedData = (data || []).map((d: any) => ({
        hostname: d.hostname,
        device_inventory_code: d.device_inventory_code,
        location_name: d.locations?.name || 'Unassigned',
        host_location: d.host_location,
        city_town_village: d.city_town_village,
        laptop_model: d.laptop_model,
        compliance_status: d.compliance_status,
        last_seen: d.last_seen ? new Date(d.last_seen).toLocaleString() : 'Never',
        os_version: d.os_version || 'Unknown',
        latitude: d.latitude,
        longitude: d.longitude,
        serial_number: d.serial_number
      }))

      setDevices(formattedData)
    } catch (error) {
      console.error('Error fetching devices:', error)
    } finally {
      setLoading(false)
    }
  }

  // Filter devices based on search text and city
  const filteredDevices = useMemo(() => {
    let filtered = devices

    // Filter by search text (hostname, inventory code)
    if (searchText.trim()) {
      const searchLower = searchText.toLowerCase()
      filtered = filtered.filter(device => 
        device.hostname?.toLowerCase().includes(searchLower) ||
        device.device_inventory_code?.toLowerCase().includes(searchLower) ||
        device.serial_number?.toLowerCase().includes(searchLower)
      )
    }

    // Filter by city
    if (cityFilter.trim()) {
      const cityLower = cityFilter.toLowerCase()
      filtered = filtered.filter(device => 
        device.city_town_village?.toLowerCase().includes(cityLower)
      )
    }

    return filtered
  }, [devices, searchText, cityFilter])

  const defaultColumnDefs: ColDef[] = useMemo(() => [
    { field: 'device_inventory_code', headerName: 'Inventory Code', sortable: true, filter: true, width: 150 },
    { field: 'hostname', headerName: 'Hostname', sortable: true, filter: true, width: 150 },
    { field: 'host_location', headerName: 'Host Location', sortable: true, filter: true, width: 180 },
    { field: 'location_name', headerName: 'Location', sortable: true, filter: true, width: 150 },
    { field: 'city_town_village', headerName: 'City/Town/Village', sortable: true, filter: true, width: 180 },
    { field: 'laptop_model', headerName: 'Laptop Model', sortable: true, filter: true, width: 180 },
    { 
      field: 'compliance_status', 
      headerName: 'Status', 
      sortable: true, 
      filter: true,
      cellRenderer: StatusRenderer,
      width: 130
    },
    { field: 'os_version', headerName: 'OS Version', sortable: true, width: 150 },
    { field: 'last_seen', headerName: 'Last Seen', sortable: true, width: 180 }
  ], [])
  
  const [columnDefs, setColumnDefs] = useState<ColDef[]>(() => {
    const saved = getSavedColumnState()
    if (saved && saved.columnDefs) {
      return saved.columnDefs.filter((col: ColDef) => col.field !== 'id')
    }
    return defaultColumnDefs
  })

  if (loading) {
    return <div>Loading device inventory...</div>
  }

  const handleRowClick = (event: any) => {
    const device = event.data as Device
    if (onDeviceSelect) {
      onDeviceSelect(device)
    }
  }

  return (
    <>
      <div className="inventory-container">
        <div className="inventory-header">
          <h2>📱 Device Inventory</h2>
          <span className="device-count">{filteredDevices.length} device{filteredDevices.length !== 1 ? 's' : ''}</span>
        </div>
        <div className="ag-theme-alpine" style={{ height: '800px', width: '100%' }}>
          <AgGridReact
            rowData={filteredDevices}
            columnDefs={columnDefs}
            defaultColDef={{
              resizable: true,
              sortable: true
            }}
            pagination={true}
            paginationPageSize={50}
            rowSelection="single"
            onRowClicked={handleRowClick}
            onColumnMoved={(event) => {
              const columnState = event.columnApi.getColumnState()
              saveColumnState({ columnState })
            }}
            onColumnResized={(event) => {
              if (event.finished) {
                const columnState = event.columnApi.getColumnState()
                saveColumnState({ columnState })
              }
            }}
            onGridReady={(event) => {
              const saved = getSavedColumnState()
              if (saved && saved.columnState) {
                // No longer filtering by 'id' since it doesn't exist
                const filteredState = saved.columnState
                event.columnApi.applyColumnState({ state: filteredState })
              }
            }}
          />
        </div>
      </div>

      {selectedDevice && (
        <div className="device-details-panel" style={{ 
          marginTop: '2rem', 
          marginBottom: '2rem',
          padding: '20px', 
          border: '2px solid #3b82f6', 
          borderRadius: '12px',
          background: 'white',
          boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
            <h3 style={{ margin: 0, color: '#1e293b' }}>Device Details: {selectedDevice.hostname}</h3>
            <button 
              onClick={onCloseDetails}
              style={{ 
                padding: '8px 16px', 
                cursor: 'pointer',
                background: '#ef4444',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                fontWeight: '600'
              }}
            >
              Close
            </button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px', marginTop: '15px' }}>
            <div><strong>Inventory Code:</strong> {selectedDevice.device_inventory_code || 'N/A'}</div>
            <div><strong>Hostname:</strong> {selectedDevice.hostname}</div>
            <div><strong>Serial Number:</strong> {selectedDevice.serial_number || 'N/A'}</div>
            <div><strong>Host Location:</strong> {selectedDevice.host_location || 'N/A'}</div>
            <div><strong>Location:</strong> {selectedDevice.location_name}</div>
            <div><strong>City/Town/Village:</strong> {selectedDevice.city_town_village || 'N/A'}</div>
            <div><strong>Laptop Model:</strong> {selectedDevice.laptop_model || 'N/A'}</div>
            <div><strong>OS Version:</strong> {selectedDevice.os_version}</div>
            <div><strong>Last Seen:</strong> {selectedDevice.last_seen}</div>
            <div>
              <strong>Status:</strong> 
              <span style={{ 
                color: selectedDevice.compliance_status === 'compliant' ? '#10b981' : 
                       selectedDevice.compliance_status === 'non_compliant' ? '#ef4444' : '#6b7280',
                fontWeight: 'bold',
                marginLeft: '8px'
              }}>
                {selectedDevice.compliance_status.toUpperCase().replace('_', ' ')}
              </span>
            </div>
            {selectedDevice.latitude && selectedDevice.longitude && (
              <>
                <div><strong>Latitude:</strong> {selectedDevice.latitude.toFixed(6)}</div>
                <div><strong>Longitude:</strong> {selectedDevice.longitude.toFixed(6)}</div>
              </>
            )}
          </div>
          {selectedDevice.compliance_status === 'non_compliant' && (
            <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#fee2e2', borderRadius: '8px', border: '1px solid #fecaca' }}>
              <strong>⚠️ Non-Compliance Reasons:</strong>
              <ul style={{ margin: '10px 0 0 20px', padding: 0 }}>
                <li>Device may be outside geofence boundaries</li>
                <li>Last seen more than 24 hours ago (if applicable)</li>
                <li>Blocked software detected (check software inventory)</li>
              </ul>
            </div>
          )}
        </div>
      )}
    </>
  )
}
