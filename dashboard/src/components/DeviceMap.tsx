import { useState, useEffect } from 'react'
import { MapContainer, TileLayer, CircleMarker, Circle, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { supabase } from '../../supabase.config'

// Fix for default marker icons in React-Leaflet
// @ts-ignore - Leaflet images don't have type declarations
import icon from 'leaflet/dist/images/marker-icon.png'
// @ts-ignore
import iconShadow from 'leaflet/dist/images/marker-shadow.png'

const DefaultIcon = L.icon({
  iconUrl: icon as string,
  shadowUrl: iconShadow as string,
  iconSize: [25, 41],
  iconAnchor: [12, 41]
})

L.Marker.prototype.options.icon = DefaultIcon

interface Device {
  id: number  // 6-digit device ID (100000-999999)
  hostname: string
  latitude: number
  longitude: number
  compliance_status: string
  location_id: string  // UUID for location
}

interface Location {
  id: string
  name: string
  latitude: number
  longitude: number
  radius_meters: number
}

interface DeviceMapProps {
  locationId: string | null
}

function MapUpdater({ locationId, devices, locations }: { locationId: string | null, devices: Device[], locations: Location[] }) {
  const map = useMap()
  
  useEffect(() => {
    if (devices.length === 0) return

    const bounds = L.latLngBounds(
      devices.map(d => [d.latitude, d.longitude] as [number, number])
    )
    map.fitBounds(bounds, { padding: [50, 50] })
  }, [devices, map])

  return null
}

export default function DeviceMap({ locationId }: DeviceMapProps) {
  const [devices, setDevices] = useState<Device[]>([])
  const [locations, setLocations] = useState<Location[]>([])
  const [loading, setLoading] = useState(true)

  async function fetchData() {
    try {
      setLoading(true)
      
      // Fetch devices (including those without assigned locations)
      let query = supabase
        .from('devices')
        .select('id, hostname, latitude, longitude, compliance_status, location_id')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)

      if (locationId) {
        query = query.eq('location_id', locationId)
      }
      // When no location filter, include all devices (including null location_id)

      const { data: devicesData, error: devicesError } = await query

      if (devicesError) throw devicesError

      // Fetch locations for geofence circles
      const { data: locationsData, error: locationsError } = await supabase
        .from('locations')
        .select('id, name, latitude, longitude, radius_meters')
        .eq('is_active', true)

      if (locationsError) throw locationsError

      setDevices(devicesData || [])
      setLocations(locationsData || [])
    } catch (error) {
      console.error('Error fetching map data:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('devices-changes')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'devices' },
        () => fetchData()
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [locationId])

  if (loading) {
    return <div className="map-loading">Loading map...</div>
  }

  // Get center point (first device or default)
  const center: [number, number] = devices.length > 0 
    ? [devices[0].latitude, devices[0].longitude]
    : [20.5937, 78.9629] // Default to India center

  return (
    <MapContainer
      center={center}
      zoom={6}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      {/* Draw geofence circles for locations */}
      {locations
        .filter(loc => !locationId || loc.id === locationId)
        .map(location => (
          <Circle
            key={location.id}
            center={[location.latitude, location.longitude]}
            radius={location.radius_meters}
            pathOptions={{
              color: '#3b82f6',
              fillColor: '#3b82f6',
              fillOpacity: 0.1,
              weight: 2
            }}
          >
            <Popup>
              <strong>{location.name}</strong><br />
              Radius: {location.radius_meters}m
            </Popup>
          </Circle>
        ))}

      {/* Draw device markers */}
      {devices.map(device => {
        const isCompliant = device.compliance_status === 'compliant'
        return (
          <CircleMarker
            key={device.id}
            center={[device.latitude, device.longitude]}
            radius={8}
            pathOptions={{
              color: isCompliant ? '#10b981' : '#ef4444',
              fillColor: isCompliant ? '#10b981' : '#ef4444',
              fillOpacity: 0.7,
              weight: 2
            }}
          >
            <Popup>
              <strong>{device.hostname}</strong><br />
              Status: {device.compliance_status}<br />
              GPS: {device.latitude.toFixed(4)}, {device.longitude.toFixed(4)}<br />
              {device.location_id ? (
                <>Location: {locations.find(l => l.id === device.location_id)?.name || 'Unknown'}</>
              ) : (
                <span style={{ color: '#ef4444' }}>⚠️ No location assigned</span>
              )}
            </Popup>
          </CircleMarker>
        )
      })}

      <MapUpdater locationId={locationId} devices={devices} locations={locations} />
    </MapContainer>
  )
}

