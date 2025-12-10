import React, { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './AddDevice.css'

export default function AddDevice({ onDeviceAdded }: { onDeviceAdded?: () => void }) {
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<{ [key: string]: string }>({})
  const [formData, setFormData] = useState({
    hostname: '',
    device_inventory_code: '',
    serial_number: '',
    host_location: '',
    city_town_village: '',
    laptop_model: '',
    latitude: '',
    longitude: '',
    os_version: '10.0.19045'
  })

  function validateCoordinates() {
    const newErrors: { [key: string]: string } = {}
    
    if (formData.latitude) {
      const lat = parseFloat(formData.latitude)
      if (isNaN(lat) || lat < -90 || lat > 90) {
        newErrors.latitude = 'Latitude must be between -90 and 90'
      }
    }
    
    if (formData.longitude) {
      const lon = parseFloat(formData.longitude)
      if (isNaN(lon) || lon < -180 || lon > 180) {
        newErrors.longitude = 'Longitude must be between -180 and 180'
      }
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    
    if (!validateCoordinates()) {
      alert('Please fix the coordinate validation errors')
      return
    }
    
    setLoading(true)
    setErrors({})

    try {
      const deviceData = {
        hostname: formData.hostname,
        device_inventory_code: formData.device_inventory_code || null,
        serial_number: formData.serial_number || null,
        host_location: formData.host_location || null,
        city_town_village: formData.city_town_village || null,
        laptop_model: formData.laptop_model || null,
        latitude: formData.latitude ? parseFloat(formData.latitude) : null,
        longitude: formData.longitude ? parseFloat(formData.longitude) : null,
        os_version: formData.os_version,
        compliance_status: 'unknown',
        last_seen: new Date().toISOString()
      }

      const { error } = await supabase
        .from('devices')
        .insert([deviceData])

      if (error) throw error

      alert('Device added successfully!')
      
      setFormData({
        hostname: '',
        device_inventory_code: '',
        serial_number: '',
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
            <label>City/Town/Village</label>
            <input
              type="text"
              value={formData.city_town_village}
              onChange={(e) => setFormData({ ...formData, city_town_village: e.target.value })}
              placeholder="Pune, Mumbai, etc."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Laptop Model</label>
            <input
              type="text"
              value={formData.laptop_model}
              onChange={(e) => setFormData({ ...formData, laptop_model: e.target.value })}
              placeholder="Dell Latitude, HP ProBook, etc."
            />
          </div>

          <div className="form-group">
            <label>Serial Number</label>
            <input
              type="text"
              value={formData.serial_number}
              onChange={(e) => setFormData({ ...formData, serial_number: e.target.value })}
              placeholder="SN123456789"
            />
          </div>
        </div>

        <div className="form-row">
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
            <label>Latitude * (-90 to 90)</label>
            <input
              type="number"
              step="any"
              min="-90"
              max="90"
              value={formData.latitude}
              onChange={(e) => {
                setFormData({ ...formData, latitude: e.target.value })
                if (errors.latitude) {
                  setErrors({ ...errors, latitude: '' })
                }
              }}
              onBlur={validateCoordinates}
              placeholder="18.5204"
              required
            />
            {errors.latitude && (
              <span style={{ color: '#ef4444', fontSize: '12px', marginTop: '4px', display: 'block' }}>
                {errors.latitude}
              </span>
            )}
          </div>

          <div className="form-group">
            <label>Longitude * (-180 to 180)</label>
            <input
              type="number"
              step="any"
              min="-180"
              max="180"
              value={formData.longitude}
              onChange={(e) => {
                setFormData({ ...formData, longitude: e.target.value })
                if (errors.longitude) {
                  setErrors({ ...errors, longitude: '' })
                }
              }}
              onBlur={validateCoordinates}
              placeholder="73.8567"
              required
            />
            {errors.longitude && (
              <span style={{ color: '#ef4444', fontSize: '12px', marginTop: '4px', display: 'block' }}>
                {errors.longitude}
              </span>
            )}
          </div>
        </div>

        <button type="submit" disabled={loading} className="submit-btn">
          {loading ? 'Adding...' : 'Add Device'}
        </button>
      </form>
    </div>
  )
}
