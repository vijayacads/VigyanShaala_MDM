import { useState, useEffect, useMemo } from 'react'
import { AgGridReact } from 'ag-grid-react'
import { ColDef } from 'ag-grid-community'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'
import { supabase } from '../../supabase.config'
import './AppInventory.css'

interface Device {
  id: string
  hostname: string
  location_name: string
  compliance_status: string
  last_seen: string
  os_version: string
}

interface AppInventoryProps {
  locationId: string | null
}

export default function AppInventory({ locationId }: AppInventoryProps) {
  const [devices, setDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(true)

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
          compliance_status,
          last_seen,
          os_version,
          locations!left(name)
        `)

      if (locationId) {
        query = query.eq('location_id', locationId)
      }

      const { data, error } = await query

      if (error) throw error

      const formattedData = (data || []).map((d: any) => ({
        id: d.id,
        hostname: d.hostname,
        location_name: d.locations?.name || 'Unknown',
        compliance_status: d.compliance_status,
        last_seen: d.last_seen ? new Date(d.last_seen).toLocaleString() : 'Never',
        os_version: d.os_version || 'Unknown'
      }))

      setDevices(formattedData)
    } catch (error) {
      console.error('Error fetching devices:', error)
    } finally {
      setLoading(false)
    }
  }

  const columnDefs: ColDef[] = useMemo(() => [
    { field: 'hostname', headerName: 'Hostname', sortable: true, filter: true, flex: 1 },
    { field: 'location_name', headerName: 'Location', sortable: true, filter: true, flex: 1 },
    { 
      field: 'compliance_status', 
      headerName: 'Status', 
      sortable: true, 
      filter: true,
      cellRenderer: (params: any) => {
        const status = params.value
        const color = status === 'compliant' ? '#10b981' : status === 'non_compliant' ? '#ef4444' : '#6b7280'
        return `<span style="color: ${color}; font-weight: bold">${status.toUpperCase()}</span>`
      },
      flex: 1
    },
    { field: 'os_version', headerName: 'OS Version', sortable: true, flex: 1 },
    { field: 'last_seen', headerName: 'Last Seen', sortable: true, flex: 1 }
  ], [])

  if (loading) {
    return <div>Loading device inventory...</div>
  }

  return (
    <div className="inventory-container">
      <div className="inventory-header">
        <h2>📱 Device Inventory</h2>
        <span className="device-count">{devices.length} devices</span>
      </div>
      <div className="ag-theme-alpine" style={{ height: '400px', width: '100%' }}>
        <AgGridReact
          rowData={devices}
          columnDefs={columnDefs}
          defaultColDef={{
            resizable: true,
            sortable: true
          }}
          pagination={true}
          paginationPageSize={50}
          rowSelection="multiple"
        />
      </div>
    </div>
  )
}

