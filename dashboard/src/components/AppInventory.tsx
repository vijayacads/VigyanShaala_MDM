import { useState, useEffect, useMemo } from 'react'
import { AgGridReact } from 'ag-grid-react'
import { ColDef, ICellRendererParams } from 'ag-grid-community'
import * as XLSX from 'xlsx'
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
  assigned_teacher?: string
  assigned_student_leader?: string
  device_imei_number?: string
  device_make?: string
  role?: string
  issue_date?: string
  wifi_ssid?: string
  performance_status?: string
  device_status?: string
  last_login_date?: string
  battery_health_percent?: number
  storage_used_percent?: number
  boot_time_avg_seconds?: number
  crash_error_count?: number
  last_health_check?: string
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
          assigned_teacher,
          assigned_student_leader,
          device_imei_number,
          device_make,
          role,
          issue_date,
          wifi_ssid,
          locations(name)
        `)

      if (locationId) {
        query = query.eq('location_id', locationId)
      }

      const { data, error } = await query

      if (error) throw error

      // Fetch health data for devices
      const hostnames = (data || []).map((d: any) => d.hostname)
      const { data: healthData } = await supabase
        .from('device_health')
        .select('device_hostname, performance_status, device_status, last_login_date, battery_health_percent, storage_used_percent, boot_time_avg_seconds, crash_error_count, last_health_check')
        .in('device_hostname', hostnames)

      const healthMap = new Map((healthData || []).map((h: any) => [h.device_hostname, h]))

      const formattedData = (data || []).map((d: any) => {
        const health = healthMap.get(d.hostname)
        return {
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
          serial_number: d.serial_number,
          assigned_teacher: d.assigned_teacher,
          assigned_student_leader: d.assigned_student_leader,
          device_imei_number: d.device_imei_number,
          device_make: d.device_make,
          role: d.role,
          issue_date: d.issue_date,
          wifi_ssid: d.wifi_ssid,
          performance_status: health?.performance_status || 'unknown',
          device_status: health?.device_status || 'unknown',
          last_login_date: health?.last_login_date || null,
          battery_health_percent: health?.battery_health_percent || null,
          storage_used_percent: health?.storage_used_percent || null,
          boot_time_avg_seconds: health?.boot_time_avg_seconds || null,
          crash_error_count: health?.crash_error_count || 0,
          last_health_check: health?.last_health_check ? new Date(health.last_health_check).toLocaleString() : 'Never'
        }
      })

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

  // Performance status renderer
  const PerformanceStatusRenderer = (params: ICellRendererParams) => {
    const status = params.value
    const color = status === 'good' ? '#10b981' : status === 'warning' ? '#f59e0b' : status === 'critical' ? '#ef4444' : '#6b7280'
    return <span style={{ color, fontWeight: 'bold' }}>{status ? status.toUpperCase() : 'UNKNOWN'}</span>
  }

  const defaultColumnDefs: ColDef[] = useMemo(() => [
    { field: 'device_inventory_code', headerName: 'Inventory Code', sortable: true, filter: true, width: 150 },
    { field: 'hostname', headerName: 'Hostname', sortable: true, filter: true, width: 150 },
    { field: 'device_imei_number', headerName: 'IMEI Number', sortable: true, filter: true, width: 150 },
    { field: 'device_make', headerName: 'Device Make', sortable: true, filter: true, width: 120 },
    { field: 'laptop_model', headerName: 'Model', sortable: true, filter: true, width: 150 },
    { field: 'os_version', headerName: 'OS & Version', sortable: true, filter: true, width: 150 },
    { field: 'role', headerName: 'Role', sortable: true, filter: true, width: 120 },
    { field: 'issue_date', headerName: 'Issue Date', sortable: true, filter: true, width: 120 },
    { field: 'host_location', headerName: 'Host Location', sortable: true, filter: true, width: 180 },
    { field: 'location_name', headerName: 'Location', sortable: true, filter: true, width: 150 },
    { field: 'city_town_village', headerName: 'City/Town/Village', sortable: true, filter: true, width: 180 },
    { field: 'serial_number', headerName: 'Serial Number', sortable: true, filter: true, width: 150 },
    { field: 'assigned_teacher', headerName: 'Assigned Teacher', sortable: true, filter: true, width: 150 },
    { field: 'assigned_student_leader', headerName: 'Student Leader', sortable: true, filter: true, width: 150 },
    { 
      field: 'compliance_status', 
      headerName: 'Compliance', 
      sortable: true, 
      filter: true,
      cellRenderer: StatusRenderer,
      width: 130
    },
    { 
      field: 'device_status', 
      headerName: 'Device Status', 
      sortable: true, 
      filter: true,
      width: 120
    },
    { 
      field: 'performance_status', 
      headerName: 'Performance', 
      sortable: true, 
      filter: true,
      cellRenderer: PerformanceStatusRenderer,
      width: 130
    },
    { field: 'battery_health_percent', headerName: 'Battery Health (%)', sortable: true, width: 140 },
    { field: 'storage_used_percent', headerName: 'Storage Used (%)', sortable: true, width: 140 },
    { field: 'boot_time_avg_seconds', headerName: 'Boot Time (s)', sortable: true, width: 130 },
    { field: 'crash_error_count', headerName: 'Crash/Error Count', sortable: true, width: 150 },
    { field: 'last_health_check', headerName: 'Last Health Check', sortable: true, width: 180 },
    { field: 'last_login_date', headerName: 'Last Login Date', sortable: true, width: 150 },
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

  const handleExportToExcel = () => {
    try {
      // Prepare data for export
      const exportData = filteredDevices.map(device => ({
        'Inventory Code': device.device_inventory_code || '',
        'Hostname': device.hostname,
        'IMEI Number': device.device_imei_number || '',
        'Device Make': device.device_make || '',
        'Model': device.laptop_model || '',
        'OS & Version': device.os_version || '',
        'Role': device.role || '',
        'Issue Date': device.issue_date || '',
        'Host Location': device.host_location || '',
        'Location': device.location_name || '',
        'City/Town/Village': device.city_town_village || '',
        'Serial Number': device.serial_number || '',
        'Assigned Teacher': device.assigned_teacher || '',
        'Assigned Student Leader': device.assigned_student_leader || '',
        'Compliance Status': device.compliance_status || '',
        'Device Status': device.device_status || '',
        'Performance Status': device.performance_status || '',
        'Battery Health (%)': device.battery_health_percent ?? '',
        'Storage Used (%)': device.storage_used_percent ?? '',
        'Boot Time (s)': device.boot_time_avg_seconds ?? '',
        'Crash/Error Count': device.crash_error_count ?? 0,
        'Last Health Check': device.last_health_check || '',
        'Last Login Date': device.last_login_date || '',
        'Last Seen': device.last_seen || '',
        'Latitude': device.latitude ?? '',
        'Longitude': device.longitude ?? ''
      }))

      // Create workbook and worksheet
      const wb = XLSX.utils.book_new()
      const ws = XLSX.utils.json_to_sheet(exportData)

      // Set column widths
      const colWidths = [
        { wch: 15 }, { wch: 20 }, { wch: 15 }, { wch: 12 }, { wch: 15 },
        { wch: 15 }, { wch: 12 }, { wch: 12 }, { wch: 18 }, { wch: 15 },
        { wch: 18 }, { wch: 15 }, { wch: 18 }, { wch: 20 }, { wch: 15 },
        { wch: 15 }, { wch: 15 }, { wch: 15 }, { wch: 15 }, { wch: 15 },
        { wch: 15 }, { wch: 18 }, { wch: 15 }, { wch: 15 }, { wch: 12 },
        { wch: 12 }
      ]
      ws['!cols'] = colWidths

      // Add worksheet to workbook
      XLSX.utils.book_append_sheet(wb, ws, 'Devices')

      // Generate filename with current date
      const date = new Date().toISOString().split('T')[0]
      const filename = `VigyanShaala-Devices-${date}.xlsx`

      // Write file
      XLSX.writeFile(wb, filename)
    } catch (error) {
      console.error('Error exporting to Excel:', error)
      alert('Failed to export to Excel. Please try again.')
    }
  }

  return (
    <>
      <div className="inventory-container">
        <div className="inventory-header">
          <h2>📱 Device Inventory</h2>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <button 
              onClick={handleExportToExcel}
              className="export-excel-btn"
              style={{
                padding: '0.5rem 1rem',
                background: 'var(--vs-gradient-primary)',
                color: 'white',
                border: '2px solid var(--vs-primary-yellow)',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: '600',
                fontFamily: 'var(--vs-font-secondary)',
                boxShadow: '0 2px 8px rgba(44, 72, 105, 0.3)',
                transition: 'all 0.3s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)'
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(44, 72, 105, 0.4)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)'
                e.currentTarget.style.boxShadow = '0 2px 8px rgba(44, 72, 105, 0.3)'
              }}
            >
              📊 Export to Excel
            </button>
            <span className="device-count">{filteredDevices.length} device{filteredDevices.length !== 1 ? 's' : ''}</span>
          </div>
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
          border: '3px solid #69ab4a', 
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
