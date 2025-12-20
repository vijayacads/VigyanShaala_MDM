import React, { useState, useEffect, useMemo } from 'react'
import { supabase } from '../../supabase.config'
import './AddDevice.css'

interface Device {
  hostname: string
  device_inventory_code?: string
  device_imei_number?: string
  device_make?: string
  host_location?: string
  host_location_state?: string
  program_name?: string
  city_town_village?: string
  role?: string
  issue_date?: string
  wifi_ssid?: string
  latitude?: number
  longitude?: number
  os_version?: string
  assigned_teacher?: string
  assigned_student_leader?: string
}

export default function AddDevice({ onDeviceAdded }: { onDeviceAdded?: () => void }) {
  const [loading, setLoading] = useState(false)
  const [editing, setEditing] = useState(false)
  const [selectedDeviceHostname, setSelectedDeviceHostname] = useState<string | null>(null)
  const [devices, setDevices] = useState<Device[]>([])
  const [deviceSearchQuery, setDeviceSearchQuery] = useState('')
  const [showDeviceDropdown, setShowDeviceDropdown] = useState(false)
  const [errors, setErrors] = useState<{ [key: string]: string }>({})
  const [formData, setFormData] = useState({
    hostname: '',
    device_inventory_code: '',
    device_imei_number: '',
    device_make: '',
    host_location: '',
    host_location_state: '',
    program_name: '',
    city_town_village: '',
    role: '',
    issue_date: '',
    wifi_ssid: '',
    latitude: '',
    longitude: '',
    os_version: '',
    assigned_teacher: '',
    assigned_student_leader: ''
  })
  const [autoFillLoading, setAutoFillLoading] = useState(false)

  useEffect(() => {
    fetchDevices()
  }, [])

  async function fetchDevices() {
    try {
      // Try with all columns first
      let { data, error } = await supabase
        .from('devices')
        .select('hostname, device_inventory_code, device_imei_number, device_make, host_location, host_location_state, program_name, city_town_village, role, issue_date, wifi_ssid, latitude, longitude, os_version, assigned_teacher, assigned_student_leader')
        .order('hostname', { ascending: true })

      // If columns don't exist, use basic columns only
      if (error && error.code === '42703') {
        const result = await supabase
          .from('devices')
          .select('hostname, device_inventory_code, host_location, city_town_village, latitude, longitude, os_version, assigned_teacher, assigned_student_leader')
          .order('hostname', { ascending: true })
        if (result.error) {
          error = result.error
        } else {
          // Map data to include missing columns as null
          data = (result.data || []).map((d: any) => ({
            ...d,
            device_imei_number: null,
            device_make: null,
            role: null,
            issue_date: null,
            wifi_ssid: null
          }))
          error = null
        }
      }

      if (error) throw error
      setDevices(data || [])
    } catch (error: any) {
      console.error('Error fetching devices:', error)
      // Set empty array on error to prevent UI breakage
      setDevices([])
    }
  }

  // Auto-fill device information
  async function handleAutoFill() {
    setAutoFillLoading(true)
    try {
      // Get hostname from system (browser environment - limited options)
      const hostname = window.location.hostname || 'unknown'
      
      // Try to detect OS version from user agent
      const userAgent = navigator.userAgent
      let osVersion = ''
      if (userAgent.includes('Windows NT 10.0')) osVersion = 'Windows 10'
      else if (userAgent.includes('Windows NT 6.3')) osVersion = 'Windows 8.1'
      else if (userAgent.includes('Windows NT 6.2')) osVersion = 'Windows 8'
      else if (userAgent.includes('Mac OS X')) osVersion = 'macOS'
      else if (userAgent.includes('Linux')) osVersion = 'Linux'
      else osVersion = 'Unknown'

      // Update form with auto-detected values
      setFormData(prev => ({
        ...prev,
        hostname: prev.hostname || hostname,
        os_version: prev.os_version || osVersion
      }))

      // Note: IMEI, device_make, and WiFi SSID require system-level access
      // These would be auto-filled by the enrollment scripts (PowerShell/Android)
      // For web form, we can only auto-fill what's available in browser context
      
      alert('Auto-filled available information. Note: IMEI, Device Make, and WiFi SSID require system-level access and will be auto-filled during device enrollment.')
    } catch (error) {
      console.error('Error auto-filling:', error)
      alert('Could not auto-fill device information')
    } finally {
      setAutoFillLoading(false)
    }
  }

  const filteredDevices = useMemo(() => {
    if (!deviceSearchQuery) return []
    const query = deviceSearchQuery.toLowerCase()
    return devices.filter(device => 
      device.hostname?.toLowerCase().includes(query) ||
      device.device_inventory_code?.toLowerCase().includes(query) ||
      device.host_location?.toLowerCase().includes(query) ||
      device.host_location_state?.toLowerCase().includes(query) ||
      device.program_name?.toLowerCase().includes(query) ||
      device.city_town_village?.toLowerCase().includes(query) ||
      device.device_imei_number?.toLowerCase().includes(query)
    ).slice(0, 10) // Limit to 10 results
  }, [deviceSearchQuery, devices])

  function loadDeviceForEdit(device: Device) {
    setEditing(true)
    setSelectedDeviceHostname(device.hostname)
    setDeviceSearchQuery(`${device.hostname}${device.device_inventory_code ? ` (${device.device_inventory_code})` : ''}`)
    setShowDeviceDropdown(false)
    setFormData({
      hostname: device.hostname || '',
      device_inventory_code: device.device_inventory_code || '',
      device_imei_number: device.device_imei_number || '',
      device_make: device.device_make || '',
      host_location: device.host_location || '',
      host_location_state: device.host_location_state || '',
      program_name: device.program_name || '',
      city_town_village: device.city_town_village || '',
      role: device.role || '',
      issue_date: device.issue_date || '',
      wifi_ssid: device.wifi_ssid || '',
      latitude: device.latitude?.toString() || '',
      longitude: device.longitude?.toString() || '',
      os_version: device.os_version || '',
      assigned_teacher: device.assigned_teacher || '',
      assigned_student_leader: device.assigned_student_leader || ''
    })
  }

  function resetForm() {
    setEditing(false)
    setSelectedDeviceHostname(null)
    setDeviceSearchQuery('')
    setFormData({
      hostname: '',
      device_inventory_code: '',
      device_imei_number: '',
      device_make: '',
      host_location: '',
      host_location_state: '',
      program_name: '',
      city_town_village: '',
      role: '',
      issue_date: '',
      wifi_ssid: '',
      latitude: '',
      longitude: '',
      os_version: '',
      assigned_teacher: '',
      assigned_student_leader: ''
    })
    setErrors({})
  }

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
        device_imei_number: formData.device_imei_number || null,
        device_make: formData.device_make || null,
        host_location: formData.host_location || null,
        host_location_state: formData.host_location_state || null,
        program_name: formData.program_name || null,
        city_town_village: formData.city_town_village || null,
        role: formData.role || null,
        issue_date: formData.issue_date || null,
        wifi_ssid: formData.wifi_ssid || null,
        latitude: formData.latitude ? parseFloat(formData.latitude) : null,
        longitude: formData.longitude ? parseFloat(formData.longitude) : null,
        os_version: formData.os_version || null,
        assigned_teacher: formData.assigned_teacher || null,
        assigned_student_leader: formData.assigned_student_leader || null
      }

      if (editing && selectedDeviceHostname) {
        const { error } = await supabase
          .from('devices')
          .update(deviceData)
          .eq('hostname', selectedDeviceHostname)

        if (error) throw error
        alert('Device updated successfully!')
      } else {
        const { error } = await supabase
          .from('devices')
          .insert([{
            ...deviceData,
            compliance_status: 'unknown',
            last_seen: new Date().toISOString()
          }])

        if (error) throw error
        alert('Device added successfully!')
      }

      resetForm()
      fetchDevices()

      if (onDeviceAdded) {
        onDeviceAdded()
      }
    } catch (error: any) {
      console.error('Error saving device:', error)
      alert(`Error: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="add-device-container">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h2>{editing ? '✏️ Edit Device' : '➕ Add New Device'}</h2>
        {!editing && (
          <button
            type="button"
            onClick={handleAutoFill}
            disabled={autoFillLoading}
            style={{
              padding: '0.5rem 1rem',
              background: 'var(--vs-gradient-primary)',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '0.9rem'
            }}
          >
            {autoFillLoading ? 'Auto-filling...' : '🔍 Auto-fill Device Info'}
          </button>
        )}
      </div>
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
            <label>Host College *</label>
            <input
              type="text"
              value={formData.host_location}
              onChange={(e) => setFormData({ ...formData, host_location: e.target.value })}
              required
              placeholder="Computer Lab, Classroom, etc."
            />
          </div>

          <div className="form-group">
            <label>Host Location (State)</label>
            <input
              type="text"
              value={formData.host_location_state}
              onChange={(e) => setFormData({ ...formData, host_location_state: e.target.value })}
              placeholder="Maharashtra, Karnataka, etc."
            />
          </div>

          <div className="form-group">
            <label>Program Name</label>
            <input
              type="text"
              value={formData.program_name}
              onChange={(e) => setFormData({ ...formData, program_name: e.target.value })}
              placeholder="Program name"
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
            <label>Device IMEI Number</label>
            <input
              type="text"
              value={formData.device_imei_number}
              onChange={(e) => setFormData({ ...formData, device_imei_number: e.target.value })}
              placeholder="Auto-filled during enrollment"
            />
          </div>

          <div className="form-group">
            <label>Device Make</label>
            <input
              type="text"
              value={formData.device_make}
              onChange={(e) => setFormData({ ...formData, device_make: e.target.value })}
              placeholder="Dell, HP, Lenovo, etc. (Auto-filled)"
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Device Role</label>
            <input
              type="text"
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value })}
              placeholder="Student device, Teacher device, etc."
            />
          </div>

          <div className="form-group">
            <label>Issue Date</label>
            <input
              type="date"
              value={formData.issue_date}
              onChange={(e) => setFormData({ ...formData, issue_date: e.target.value })}
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>WiFi SSID</label>
            <input
              type="text"
              value={formData.wifi_ssid}
              onChange={(e) => setFormData({ ...formData, wifi_ssid: e.target.value })}
              placeholder="Auto-detected during enrollment"
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

          <div className="form-group">
            <label>Assigned Teacher</label>
            <input
              type="text"
              value={formData.assigned_teacher}
              onChange={(e) => setFormData({ ...formData, assigned_teacher: e.target.value })}
              placeholder="Teacher name or ID"
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label>Assigned Student Leader</label>
            <input
              type="text"
              value={formData.assigned_student_leader}
              onChange={(e) => setFormData({ ...formData, assigned_student_leader: e.target.value })}
              placeholder="Student leader name or ID"
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

        <div className="form-actions">
          <button type="submit" disabled={loading} className="submit-btn">
            {loading ? (editing ? 'Updating...' : 'Adding...') : (editing ? 'Update Device' : 'Add Device')}
          </button>
          {editing && (
            <button type="button" onClick={resetForm} className="cancel-btn">
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="edit-device-section">
        <h3>📝 Edit Existing Device</h3>
        <p className="edit-section-description">
          Search and select a device to edit its details:
        </p>
        <div className="device-search-wrapper" style={{ position: 'relative' }}>
          <input
            type="text"
            placeholder="Type to search by name, inventory code, location, city, or serial number..."
            value={deviceSearchQuery}
            onChange={(e) => {
              setDeviceSearchQuery(e.target.value)
              setShowDeviceDropdown(true)
              if (!e.target.value) {
                setEditing(false)
                setSelectedDeviceHostname(null)
              }
            }}
            onFocus={() => {
              if (deviceSearchQuery) setShowDeviceDropdown(true)
            }}
            className="device-search-input"
          />
          {showDeviceDropdown && filteredDevices.length > 0 && (
            <div className="device-dropdown">
              {filteredDevices.map(device => (
                <div
                  key={device.hostname}
                  onClick={() => loadDeviceForEdit(device)}
                  className="device-dropdown-item"
                >
                  <div className="device-dropdown-name">{device.hostname}</div>
                  <div className="device-dropdown-details">
                    {device.device_inventory_code && <span>{device.device_inventory_code}</span>}
                    {device.host_location && <span>📍 {device.host_location}</span>}
                    {device.city_town_village && <span>🏙️ {device.city_town_village}</span>}
                  </div>
                </div>
              ))}
            </div>
          )}
          {deviceSearchQuery && filteredDevices.length === 0 && showDeviceDropdown && (
            <div className="device-dropdown">
              <div className="device-dropdown-empty">No devices found matching "{deviceSearchQuery}"</div>
            </div>
          )}
        </div>
        {devices.length > 0 && !deviceSearchQuery && (
          <p className="edit-hint">
            💡 Start typing to search through {devices.length} devices
          </p>
        )}
      </div>
    </div>
  )
}

