import { useState, useEffect, useMemo } from 'react'
import { AgGridReact } from 'ag-grid-react'
import { ColDef, ICellRendererParams } from 'ag-grid-community'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'
import { supabase } from '../../supabase.config'
import './AppInventory.css'

interface Device {
  id: number  // 6-digit device ID (100000-999999)
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
  onDeviceSelect?: (device: Device) => void
}

// Status cell renderer component
const StatusRenderer = (params: ICellRendererParams) => {
  const status = params.value
  const color = status === 'compliant' ? '#10b981' : status === 'non_compliant' ? '#ef4444' : '#6b7280'
  return <span style={{ color, fontWeight: 'bold' }}>{status.toUpperCase().replace('_', ' ')}</span>
}

export default function AppInventory({ locationId, onDeviceSelect }: AppInventoryProps) {
  const [devices, setDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null)
  
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
          id,
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
        id: d.id,
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

  const defaultColumnDefs: ColDef[] = useMemo(() => [
    { field: 'id', headerName: 'Device ID', sortable: true, filter: true, width: 100 },
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
      return saved.columnDefs
    }
    return defaultColumnDefs
  })

  if (loading) {
    return <div>Loading device inventory...</div>
  }

  const handleRowClick = (event: any) => {
    const device = event.data as Device
    setSelectedDevice(device)
    if (onDeviceSelect) {
      onDeviceSelect(device)
    }
  }

  return (
    <div className="inventory-container">
      <div className="inventory-header">
        <h2>📱 Device Inventory</h2>
        <span className="device-count">{devices.length} devices</span>
      </div>
      <div className="ag-theme-alpine" style={{ height: '800px', width: '100%' }}>
        <AgGridReact
          rowData={devices}
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
              event.columnApi.applyColumnState({ state: saved.columnState })
            }
          }}
        />
      </div>

      {selectedDevice && (
        <div className="device-details" style={{ marginTop: '20px', padding: '15px', border: '1px solid #ddd', borderRadius: '8px' }}>
          <h3>Device Details: {selectedDevice.hostname}</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '10px' }}>
            <div><strong>Device ID:</strong> {selectedDevice.id}</div>
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
            <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#fee2e2', borderRadius: '4px' }}>
              <strong>⚠️ Non-Compliance Reasons:</strong>
              <ul style={{ margin: '8px 0 0 20px' }}>
                <li>Device may be outside geofence boundaries</li>
                <li>Last seen more than 24 hours ago (if applicable)</li>
                <li>Blocked software detected (check software inventory)</li>
              </ul>
            </div>
          )}
          <button 
            onClick={() => setSelectedDevice(null)}
            style={{ marginTop: '10px', padding: '8px 16px', cursor: 'pointer' }}
          >
            Close Details
          </button>
        </div>
      )}
    </div>
  )
}

