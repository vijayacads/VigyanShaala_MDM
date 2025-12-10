import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './DeviceSearchFilter.css'

interface Location {
  id: string
  name: string
}

interface DeviceSearchFilterProps {
  onFilterChange: (filters: {
    searchText: string
    locationId: string | null
    city: string
  }) => void
}

export default function DeviceSearchFilter({ onFilterChange }: DeviceSearchFilterProps) {
  const [locations, setLocations] = useState<Location[]>([])
  const [searchText, setSearchText] = useState('')
  const [selectedLocation, setSelectedLocation] = useState<string>('')
  const [cityFilter, setCityFilter] = useState('')

  useEffect(() => {
    fetchLocations()
  }, [])

  useEffect(() => {
    onFilterChange({
      searchText,
      locationId: selectedLocation || null,
      city: cityFilter
    })
  }, [searchText, selectedLocation, cityFilter])

  async function fetchLocations() {
    try {
      const { data, error } = await supabase
        .from('locations')
        .select('id, name')
        .eq('is_active', true)
        .order('name')

      if (error) throw error
      setLocations(data || [])
    } catch (error) {
      console.error('Error fetching locations:', error)
    }
  }

  function handleClear() {
    setSearchText('')
    setSelectedLocation('')
    setCityFilter('')
  }

  return (
    <div className="device-search-filter">
      <div className="filter-row">
        <div className="filter-group">
          <label>🔍 Search</label>
          <input
            type="text"
            placeholder="Search by name, inventory code, hostname..."
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            className="search-input"
          />
        </div>

        <div className="filter-group">
          <label>📍 Location</label>
          <select
            value={selectedLocation}
            onChange={(e) => setSelectedLocation(e.target.value)}
            className="filter-select"
          >
            <option value="">All Locations</option>
            {locations.map((location) => (
              <option key={location.id} value={location.id}>
                {location.name}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-group">
          <label>🏙️ City/Town/Village</label>
          <input
            type="text"
            placeholder="Filter by city..."
            value={cityFilter}
            onChange={(e) => setCityFilter(e.target.value)}
            className="filter-input"
          />
        </div>

        {(searchText || selectedLocation || cityFilter) && (
          <button onClick={handleClear} className="clear-filters-btn">
            Clear Filters
          </button>
        )}
      </div>
    </div>
  )
}
