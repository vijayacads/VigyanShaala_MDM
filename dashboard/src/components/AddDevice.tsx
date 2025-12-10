import React, { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './AddDevice.css'

interface Location {
  id: string
  name: string
}

export default function AddDevice({ onDeviceAdded }: { onDeviceAdded?: () => void }) {
  const [locations, setLocations] = useState<Location[]>([])
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState({
    hostname: '',
    device_inventory_code: '',
    serial_number: '',
    location_id: '',
    host_location: '',
    city_town_village: '',
    laptop_model: '',
    latitude: '',
    longitude: '',
    os_version: '10.0.19045'
  })

  useEffect(() => {
    fetchLocations()
  }, [])

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

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)

    try {
      const deviceData = {
        hostname: formData.hostname,
        device_inventory_code: formData.device_inventory_code || null,
        serial_number: formData.serial_number || null,
        location_id: formData.location_id || null,
        host_location: formData.host_location || null,
        city_town_village: formData.city_town_village || null,
        laptop_model: formData.laptop_model || null,
        latitude: formData.latitude ? parseFloat(formData.latitude) : null,
        longitude: formData.longitude ? parseFloat(formData.longitude) : null,
        os_version: formData.os_version,
        compliance_status: 'unknown',  // Automated
        last_seen: new Date().toISOString()  // Automated
      }

      const { error } = await supabase
        .from('devices')
        .insert([deviceData])

      if (error) throw error

      alert('Device added successfully!')
      
      // Reset form
      setFormData({
        hostname: '',
        device_inventory_code: '',
        serial_number: '',
        location_id: '',
        host_location: '',
        city_town_village: '',
        laptop_model: '',
        latitude: '',
        longitude: '',
        os_version: '10.0.19045'
      })

      if (onDeviceAdded) {
        onDeviceAdded()
      }
    } catch (error: any) {
      console.error('Error adding device:', error)
      alert(`Error: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="add-device-container">
      <h2>➕ Add New Device</h2>
      <form onSubmit={handleSubmit} className="add-device-form">
        <div className="form-row">
          <div className="form-group">
            <label>Device Inventory Code *</label>
            <input
              type="text"
              value={formData.device_inventory_code}
              onChange={(e) => setFormData({ ...formData, device_inventory_code: e.target.value })}
              required
              placeholder="INV-001"
            />
          </div>

          <div className="form-group">
            <label>Hostname *</label>
            <input
              type="text"
              value={formData.hostname}
              onChange={(e) => setFormData({ ...formData, hostname: e.target.value })}
              required
              placeholder="PC-LAB-001"
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Host Location (College, Lab etc.) *</label>
            <input
              type="text"
              value={formData.host_location}
              onChange={(e) => setFormData({ ...formData, host_location: e.target.value })}
              required
              placeholder="Computer Lab, Classroom, etc."
            />
          </div>

          <div className="form-group">
            <label>Location</label>
            <select
              value={formData.location_id}
              onChange={(e) => setFormData({ ...formData, location_id: e.target.value })}
            >
              <option value="">Select Location...</option>
              {locations.map(loc => (
                <option key={loc.id} value={loc.id}>{loc.name}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>City/Town/Village</label>
            <input
              type="text"
              value={formData.city_town_village}
              onChange={(e) => setFormData({ ...formData, city_town_village: e.target.value })}
              placeholder="Pune, Mumbai, etc."
            />
          </div>

          <div className="form-group">
            <label>Laptop Model</label>
            <input
              type="text"
              value={formData.laptop_model}
              onChange={(e) => setFormData({ ...formData, laptop_model: e.target.value })}
              placeholder="Dell Latitude, HP ProBook, etc."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Serial Number</label>
            <input
              type="text"
              value={formData.serial_number}
              onChange={(e) => setFormData({ ...formData, serial_number: e.target.value })}
              placeholder="SN123456789"
            />
          </div>

          <div className="form-group">
            <label>OS Version</label>
            <input
              type="text"
              value={formData.os_version}
              onChange={(e) => setFormData({ ...formData, os_version: e.target.value })}
              placeholder="10.0.19045"
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Latitude</label>
            <input
              type="number"
              step="any"
              value={formData.latitude}
              onChange={(e) => setFormData({ ...formData, latitude: e.target.value })}
              placeholder="18.5204"
            />
          </div>

          <div className="form-group">
            <label>Longitude</label>
            <input
              type="number"
              step="any"
              value={formData.longitude}
              onChange={(e) => setFormData({ ...formData, longitude: e.target.value })}
              placeholder="73.8567"
            />
          </div>
        </div>


        <button type="submit" disabled={loading} className="submit-btn">
          {loading ? 'Adding...' : 'Add Device'}
        </button>
      </form>
    </div>
  )
}
