import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './TamperDetection.css'

interface TamperEvent {
  id: string
  device_hostname: string
  event_type: string
  severity: 'low' | 'medium' | 'high' | 'critical'
  detected_at: string
  last_seen_before: string
  details: any
  resolved_at: string | null
  resolved_by: string | null
  notes: string | null
}

interface Device {
  hostname: string
  device_inventory_code?: string
  last_seen: string
}

export default function TamperDetection() {
  const [tamperEvents, setTamperEvents] = useState<TamperEvent[]>([])
  const [offlineDevices, setOfflineDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(false)
  const [filter, setFilter] = useState<'all' | 'unresolved' | 'critical' | 'high'>('unresolved')

  useEffect(() => {
    fetchTamperEvents()
    fetchOfflineDevices()
    // Refresh every 30 seconds
    const interval = setInterval(() => {
      fetchTamperEvents()
      fetchOfflineDevices()
    }, 30000)
    return () => clearInterval(interval)
  }, [filter])

  async function fetchTamperEvents() {
    try {
      let query = supabase
        .from('tamper_events')
        .select('*')
        .order('detected_at', { ascending: false })
        .limit(100)

      if (filter === 'unresolved') {
        query = query.is('resolved_at', null)
      } else if (filter === 'critical' || filter === 'high') {
        query = query.eq('severity', filter).is('resolved_at', null)
      }

      const { data, error } = await query
      if (error) throw error
      setTamperEvents(data || [])
    } catch (error) {
      console.error('Error fetching tamper events:', error)
    }
  }

  async function fetchOfflineDevices() {
    try {
      const { data, error } = await supabase
        .rpc('detect_offline_devices')

      if (error) throw error

      // Get device details
      if (data && data.length > 0) {
        const hostnames = data.map((d: any) => d.device_hostname)
        const { data: devices, error: devicesError } = await supabase
          .from('devices')
          .select('hostname, device_inventory_code, last_seen')
          .in('hostname', hostnames)

        if (!devicesError && devices) {
          const deviceMap = new Map(devices.map((d: any) => [d.hostname, d]))
          const offline = data.map((d: any) => ({
            ...deviceMap.get(d.device_hostname),
            minutes_offline: d.minutes_offline,
            severity: d.severity
          }))
          setOfflineDevices(offline)
        }
      } else {
        setOfflineDevices([])
      }
    } catch (error) {
      console.error('Error fetching offline devices:', error)
    }
  }

  async function resolveEvent(eventId: string, notes: string) {
    setLoading(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()
      const { error } = await supabase
        .from('tamper_events')
        .update({
          resolved_at: new Date().toISOString(),
          resolved_by: user?.id || null,
          notes: notes || null
        })
        .eq('id', eventId)

      if (error) throw error
      await fetchTamperEvents()
    } catch (error) {
      console.error('Error resolving event:', error)
      alert('Failed to resolve event')
    } finally {
      setLoading(false)
    }
  }

  function getSeverityColor(severity: string) {
    switch (severity) {
      case 'critical': return '#e74c3c'
      case 'high': return '#e67e22'
      case 'medium': return '#f39c12'
      case 'low': return '#3498db'
      default: return '#95a5a6'
    }
  }

  function formatTimeAgo(minutes: number) {
    if (minutes < 60) return `${Math.round(minutes)} minutes`
    if (minutes < 1440) return `${Math.round(minutes / 60)} hours`
    return `${Math.round(minutes / 1440)} days`
  }

  return (
    <div className="tamper-detection-container">
      <div className="tamper-header">
        <h2>🛡️ Tamper Detection</h2>
        <div className="tamper-filters">
          <button
            className={filter === 'unresolved' ? 'active' : ''}
            onClick={() => setFilter('unresolved')}
          >
            Unresolved
          </button>
          <button
            className={filter === 'critical' ? 'active' : ''}
            onClick={() => setFilter('critical')}
          >
            Critical
          </button>
          <button
            className={filter === 'high' ? 'active' : ''}
            onClick={() => setFilter('high')}
          >
            High
          </button>
          <button
            className={filter === 'all' ? 'active' : ''}
            onClick={() => setFilter('all')}
          >
            All Events
          </button>
        </div>
      </div>

      {/* Offline Devices - Devices to Collect */}
      <div className="offline-devices-section">
        <h3>⚠️ Devices to Collect (Offline)</h3>
        {offlineDevices.length === 0 ? (
          <div className="no-tamper">✅ All devices are online</div>
        ) : (
          <div className="offline-devices-list">
            {offlineDevices.map((device: any) => (
              <div
                key={device.hostname}
                className="offline-device-card"
                style={{ borderLeftColor: getSeverityColor(device.severity) }}
              >
                <div className="device-info">
                  <div className="device-name">{device.hostname}</div>
                  {device.device_inventory_code && (
                    <div className="device-code">{device.device_inventory_code}</div>
                  )}
                </div>
                <div className="device-status">
                  <span className="severity-badge" style={{ backgroundColor: getSeverityColor(device.severity) }}>
                    {device.severity.toUpperCase()}
                  </span>
                  <div className="offline-time">
                    Offline for {formatTimeAgo(device.minutes_offline)}
                  </div>
                  <div className="last-seen">
                    Last seen: {new Date(device.last_seen).toLocaleString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Tamper Events History */}
      <div className="tamper-events-section">
        <h3>📋 Tamper Events History</h3>
        {tamperEvents.length === 0 ? (
          <div className="no-tamper">No tamper events found</div>
        ) : (
          <table className="tamper-events-table">
            <thead>
              <tr>
                <th>Device</th>
                <th>Event Type</th>
                <th>Severity</th>
                <th>Detected At</th>
                <th>Time Offline</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {tamperEvents.map(event => (
                <tr key={event.id}>
                  <td>{event.device_hostname}</td>
                  <td>{event.event_type}</td>
                  <td>
                    <span className="severity-badge" style={{ backgroundColor: getSeverityColor(event.severity) }}>
                      {event.severity}
                    </span>
                  </td>
                  <td>{new Date(event.detected_at).toLocaleString()}</td>
                  <td>
                    {event.details?.minutes_offline
                      ? formatTimeAgo(event.details.minutes_offline)
                      : '-'}
                  </td>
                  <td>
                    {event.resolved_at ? (
                      <span className="resolved-badge">✅ Resolved</span>
                    ) : (
                      <span className="unresolved-badge">⚠️ Active</span>
                    )}
                  </td>
                  <td>
                    {!event.resolved_at && (
                      <button
                        className="resolve-btn"
                        onClick={() => {
                          const notes = prompt('Add notes (optional):')
                          if (notes !== null) {
                            resolveEvent(event.id, notes)
                          }
                        }}
                        disabled={loading}
                      >
                        Mark Resolved
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
