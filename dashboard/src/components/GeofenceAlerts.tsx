import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './GeofenceAlerts.css'

interface GeofenceAlert {
  id: string
  device_id: string
  location_id: string
  violation_type: string
  latitude: number
  longitude: number
  distance_meters: number
  created_at: string
  resolved_at: string | null
  device: {
    hostname: string
  }
  location: {
    name: string
  }
}

interface GeofenceAlertsProps {
  locationId: string | null
}

export default function GeofenceAlerts({ locationId }: GeofenceAlertsProps) {
  const [alerts, setAlerts] = useState<GeofenceAlert[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchAlerts()
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('geofence-alerts')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'geofence_alerts' },
        () => fetchAlerts()
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [locationId])

  async function fetchAlerts() {
    try {
      setLoading(true)
      
      let query = supabase
        .from('geofence_alerts')
        .select(`
          id,
          device_id,
          location_id,
          violation_type,
          latitude,
          longitude,
          distance_meters,
          created_at,
          resolved_at,
          devices!left(hostname),
          locations!left(name)
        `)
        .order('created_at', { ascending: false })
        .limit(100)

      if (locationId) {
        query = query.eq('location_id', locationId)
      }

      const { data, error } = await query

      if (error) throw error

      const formattedAlerts = (data || []).map((alert: any) => ({
        ...alert,
        device: { hostname: alert.devices?.hostname || 'Unknown' },
        location: { name: alert.locations?.name || 'Unknown' }
      }))

      setAlerts(formattedAlerts)
    } catch (error) {
      console.error('Error fetching alerts:', error)
    } finally {
      setLoading(false)
    }
  }

  async function resolveAlert(alertId: string) {
    try {
      const { error } = await supabase
        .from('geofence_alerts')
        .update({ resolved_at: new Date().toISOString() })
        .eq('id', alertId)

      if (error) throw error
      fetchAlerts()
    } catch (error) {
      console.error('Error resolving alert:', error)
    }
  }

  const unresolvedAlerts = alerts.filter(a => !a.resolved_at)
  const resolvedAlerts = alerts.filter(a => a.resolved_at)

  if (loading) {
    return <div>Loading alerts...</div>
  }

  return (
    <div className="alerts-container">
      <div className="alerts-header">
        <h2>🚨 Geofence Alerts</h2>
        <div className="alerts-stats">
          <span className="stat unresolved">⚠️ Unresolved: {unresolvedAlerts.length}</span>
          <span className="stat resolved">✅ Resolved: {resolvedAlerts.length}</span>
        </div>
      </div>

      <div className="alerts-list">
        <h3>Active Violations</h3>
        {unresolvedAlerts.length === 0 ? (
          <p className="no-alerts">No active violations</p>
        ) : (
          <table className="alerts-table">
            <thead>
              <tr>
                <th>Device</th>
                <th>Location</th>
                <th>Distance</th>
                <th>Time</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {unresolvedAlerts.map(alert => (
                <tr key={alert.id} className="alert-row unresolved">
                  <td>{alert.device.hostname}</td>
                  <td>{alert.location.name}</td>
                  <td>{alert.distance_meters}m outside</td>
                  <td>{new Date(alert.created_at).toLocaleString()}</td>
                  <td>
                    <button 
                      onClick={() => resolveAlert(alert.id)}
                      className="resolve-btn"
                    >
                      Resolve
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {resolvedAlerts.length > 0 && (
          <>
            <h3>Resolved</h3>
            <table className="alerts-table">
              <thead>
                <tr>
                  <th>Device</th>
                  <th>Location</th>
                  <th>Distance</th>
                  <th>Resolved</th>
                </tr>
              </thead>
              <tbody>
                {resolvedAlerts.slice(0, 10).map(alert => (
                  <tr key={alert.id} className="alert-row resolved">
                    <td>{alert.device.hostname}</td>
                    <td>{alert.location.name}</td>
                    <td>{alert.distance_meters}m outside</td>
                    <td>{new Date(alert.resolved_at!).toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>
    </div>
  )
}

