import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './LocationFilter.css'

interface Location {
  id: string
  name: string
  latitude: number
  longitude: number
  radius_meters: number
}

interface LocationFilterProps {
  selectedLocation: string | null
  onLocationChange: (locationId: string | null) => void
}

export default function LocationFilter({ selectedLocation, onLocationChange }: LocationFilterProps) {
  const [locations, setLocations] = useState<Location[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchLocations()
  }, [])

  async function fetchLocations() {
    try {
      const { data, error } = await supabase
        .from('locations')
        .select('id, name, latitude, longitude, radius_meters')
        .eq('is_active', true)
        .order('name')

      if (error) throw error
      setLocations(data || [])
    } catch (error) {
      console.error('Error fetching locations:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return <div>Loading locations...</div>
  }

  return (
    <div className="location-filter">
      <h2 className="filter-title">📍 Filter by Location</h2>
      <select
        value={selectedLocation || ''}
        onChange={(e) => onLocationChange(e.target.value || null)}
        className="location-select"
      >
        <option value="">All Locations ({locations.length})</option>
        {locations.map((location) => (
          <option key={location.id} value={location.id}>
            {location.name} ({location.radius_meters}m)
          </option>
        ))}
      </select>

      {selectedLocation && (
        <div className="location-info">
          {(() => {
            const location = locations.find(l => l.id === selectedLocation)
            return location ? (
              <div className="location-details">
                <div className="detail-item">
                  <span className="detail-label">Radius:</span>
                  <span className="detail-value">{location.radius_meters}m</span>
                </div>
                <div className="detail-item">
                  <span className="detail-label">Coordinates:</span>
                  <span className="detail-value">{location.latitude.toFixed(4)}, {location.longitude.toFixed(4)}</span>
                </div>
              </div>
            ) : null
          })()}
        </div>
      )}
    </div>
  )
}

