import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './DeviceControl.css'

interface DeviceCommand {
  id: string
  device_hostname: string
  command_type: 'lock' | 'unlock' | 'clear_cache' | 'buzz' | 'broadcast_message'
  message?: string
  target_type?: 'single' | 'location' | 'all'
  target_location_id?: string
  duration?: number
  status: 'pending' | 'completed' | 'failed' | 'dismissed' | 'expired'
  created_at: string
  executed_at?: string
  error_message?: string
}

interface DeviceControlProps {
  selectedDevice?: string | null
  locationId?: string | null
}

export default function DeviceControl({ selectedDevice, locationId }: DeviceControlProps) {
  const [devices, setDevices] = useState<any[]>([])
  const [locations, setLocations] = useState<any[]>([])
  const [commandHistory, setCommandHistory] = useState<DeviceCommand[]>([])
  const [loading, setLoading] = useState(false)
  const [buzzDuration, setBuzzDuration] = useState(5)
  const [broadcastMessage, setBroadcastMessage] = useState('')
  const [selectedBroadcastDevices, setSelectedBroadcastDevices] = useState<string[]>([])
  const [deviceSearchQuery, setDeviceSearchQuery] = useState('')
  const [localSelectedDevice, setLocalSelectedDevice] = useState<string | null>(selectedDevice || null)
  const [selectedControlDevices, setSelectedControlDevices] = useState<string[]>([])
  const [controlDeviceSearchQuery, setControlDeviceSearchQuery] = useState('')

  useEffect(() => {
    fetchDevices()
    fetchLocations()
    const deviceToUse = selectedDevice || localSelectedDevice || selectedControlDevices[0]
    if (deviceToUse) {
      fetchCommandHistory(deviceToUse)
    }
  }, [selectedDevice, localSelectedDevice, selectedControlDevices])

  async function fetchDevices() {
    try {
      const { data, error } = await supabase
        .from('devices')
        .select('hostname, device_inventory_code, location_id')
        .order('hostname')
      
      if (error) throw error
      setDevices(data || [])
    } catch (error) {
      console.error('Error fetching devices:', error)
    }
  }

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

  async function fetchCommandHistory(deviceHostname: string) {
    try {
      // Normalize hostname for consistent matching (uppercase)
      const normalizedHostname = deviceHostname.trim().toUpperCase()
      
      // Try exact match first
      let { data, error } = await supabase
        .from('device_commands')
        .select('*')
        .eq('device_hostname', normalizedHostname)
        .order('created_at', { ascending: false })
        .limit(50)
      
      // If no results, try case-insensitive search by fetching all and filtering
      if ((!data || data.length === 0) && !error) {
        const { data: allData, error: allError } = await supabase
          .from('device_commands')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(200)
        
        if (!allError && allData) {
          data = allData.filter(cmd => 
            cmd.device_hostname && 
            cmd.device_hostname.trim().toUpperCase() === normalizedHostname
          )
        }
      }
      
      if (error) throw error
      setCommandHistory(data || [])
    } catch (error) {
      console.error('Error fetching command history:', error)
      setCommandHistory([])
    }
  }

  async function sendCommand(commandType: 'lock' | 'unlock' | 'clear_cache' | 'buzz', deviceHostnames: string | string[]) {
    const targetDevices = Array.isArray(deviceHostnames) ? deviceHostnames : [deviceHostnames]
    
    if (targetDevices.length === 0) {
      alert('Please select at least one device')
      return
    }

    const deviceList = targetDevices.length === 1 
      ? targetDevices[0] 
      : `${targetDevices.length} devices`
    
    if (!confirm(`Are you sure you want to ${commandType} ${deviceList}?`)) {
      return
    }

    setLoading(true)
    try {
      // Send command to all selected devices
      const commands = targetDevices.map(hostname => {
        const normalizedHostname = hostname.trim().toUpperCase()
        return {
          device_hostname: normalizedHostname,
          command_type: commandType,
          status: 'pending' as const,
          ...(commandType === 'buzz' && { duration: buzzDuration })
        }
      })

      const { error } = await supabase
        .from('device_commands')
        .insert(commands)

      if (error) throw error

      alert(`Command sent successfully! ${targetDevices.length} device(s) will execute ${commandType} command.`)
      // Refresh command history if viewing one of the target devices
      const deviceToUse = selectedDevice || localSelectedDevice || selectedControlDevices[0]
      if (deviceToUse && targetDevices.includes(deviceToUse)) {
        setTimeout(() => fetchCommandHistory(deviceToUse), 1000)
      }
    } catch (error: any) {
      console.error('Error sending command:', error)
      alert(`Error: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  async function sendBroadcastMessage() {
    if (!broadcastMessage.trim()) {
      alert('Please enter a message')
      return
    }

    if (selectedBroadcastDevices.length === 0) {
      alert('Please select at least one device')
      return
    }

    setLoading(true)
    try {
      // Normalize hostnames: trim and convert to uppercase for consistent matching
      const commands = selectedBroadcastDevices.map(hostname => ({
        device_hostname: hostname.trim().toUpperCase(),
        command_type: 'broadcast_message' as const,
        message: broadcastMessage,
        target_type: 'single' as const,
        status: 'pending' as const
      }))

      const { error } = await supabase
        .from('device_commands')
        .insert(commands)

      if (error) throw error

      alert(`Broadcast message sent to ${selectedBroadcastDevices.length} device(s)!`)
      setBroadcastMessage('')
      setSelectedBroadcastDevices([])
      
      // Refresh command history if viewing one of the target devices
      const deviceToUse = selectedDevice || localSelectedDevice
      if (deviceToUse && selectedBroadcastDevices.includes(deviceToUse)) {
        setTimeout(() => fetchCommandHistory(deviceToUse), 1000)
      }
    } catch (error: any) {
      console.error('Error sending broadcast:', error)
      alert(`Error: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const filteredDevices = devices.filter(device => {
    if (!deviceSearchQuery.trim()) return true
    const query = deviceSearchQuery.toLowerCase()
    return device.hostname?.toLowerCase().includes(query) ||
           device.device_inventory_code?.toLowerCase().includes(query)
  })

  const filteredControlDevices = devices.filter(device => {
    if (!controlDeviceSearchQuery.trim()) return true
    const query = controlDeviceSearchQuery.toLowerCase()
    return device.hostname?.toLowerCase().includes(query) ||
           device.device_inventory_code?.toLowerCase().includes(query)
  })

  const handleSelectAll = () => {
    if (filteredDevices.length === 0) return
    if (selectedBroadcastDevices.length === filteredDevices.length && 
        filteredDevices.every(d => selectedBroadcastDevices.includes(d.hostname))) {
      setSelectedBroadcastDevices([])
    } else {
      setSelectedBroadcastDevices(filteredDevices.map(d => d.hostname))
    }
  }

  const handleDeviceToggle = (hostname: string) => {
    setSelectedBroadcastDevices(prev => 
      prev.includes(hostname)
        ? prev.filter(h => h !== hostname)
        : [...prev, hostname]
    )
  }

  const handleControlSelectAll = () => {
    if (filteredControlDevices.length === 0) return
    if (selectedControlDevices.length === filteredControlDevices.length && 
        filteredControlDevices.every(d => selectedControlDevices.includes(d.hostname))) {
      setSelectedControlDevices([])
      setCommandHistory([])
    } else {
      const newSelection = filteredControlDevices.map(d => d.hostname)
      setSelectedControlDevices(newSelection)
      if (newSelection.length > 0) {
        fetchCommandHistory(newSelection[0])
      }
    }
  }

  const handleControlDeviceToggle = (hostname: string) => {
    setSelectedControlDevices(prev => {
      const newSelection = prev.includes(hostname)
        ? prev.filter(h => h !== hostname)
        : [...prev, hostname]
      // Update command history to show first selected device
      if (newSelection.length > 0) {
        fetchCommandHistory(newSelection[0])
      } else {
        setCommandHistory([])
      }
      return newSelection
    })
  }

  const targetDevice = selectedDevice || localSelectedDevice || selectedControlDevices[0] || devices[0]?.hostname

  return (
    <div className="device-control-container">
      <h2>🎮 Device Control & Messaging</h2>

      {/* Device Selection */}
      <div className="control-section">
        <h3>Select Device(s) for Control</h3>
        <div className="device-selection-container">
          <div className="device-search-header">
            <input
              type="text"
              placeholder="🔍 Search devices by name or inventory code..."
              value={controlDeviceSearchQuery}
              onChange={(e) => setControlDeviceSearchQuery(e.target.value)}
              className="device-search-input"
            />
            <button onClick={handleControlSelectAll} className="select-all-btn">
              {selectedControlDevices.length === filteredControlDevices.length && filteredControlDevices.length > 0
                ? 'Deselect All' 
                : 'Select All'} ({selectedControlDevices.length}/{filteredControlDevices.length})
            </button>
          </div>
          <div className="device-list-multiselect">
            {filteredControlDevices.length === 0 ? (
              <p className="no-devices">No devices found matching your search.</p>
            ) : (
              filteredControlDevices.map(device => (
                <label key={device.hostname} className="device-multiselect-item">
                  <input
                    type="checkbox"
                    checked={selectedControlDevices.includes(device.hostname)}
                    onChange={() => handleControlDeviceToggle(device.hostname)}
                  />
                  <span>{device.hostname} {device.device_inventory_code ? `(${device.device_inventory_code})` : ''}</span>
                </label>
              ))
            )}
          </div>
          {selectedControlDevices.length > 0 && (
            <div className="selected-count">
              {selectedControlDevices.length} device(s) selected
            </div>
          )}
        </div>
      </div>

      {/* Device Control Buttons */}
      {selectedControlDevices.length > 0 && (
        <div className="control-section">
          <h3>Device Controls</h3>
          <div className="control-buttons">
            <button
              onClick={() => sendCommand('lock', selectedControlDevices)}
              disabled={loading}
              className="control-btn lock-btn"
            >
              🔒 Lock Device{selectedControlDevices.length > 1 ? 's' : ''}
            </button>
            <button
              onClick={() => sendCommand('unlock', selectedControlDevices)}
              disabled={loading}
              className="control-btn unlock-btn"
            >
              🔓 Unlock Device{selectedControlDevices.length > 1 ? 's' : ''}
            </button>
            <button
              onClick={() => sendCommand('clear_cache', selectedControlDevices)}
              disabled={loading}
              className="control-btn cache-btn"
            >
              🗑️ Clear Cache
            </button>
            <div className="buzz-control">
              <button
                onClick={() => sendCommand('buzz', selectedControlDevices)}
                disabled={loading}
                className="control-btn buzz-btn"
              >
                🔊 Buzz Device{selectedControlDevices.length > 1 ? 's' : ''}
              </button>
              <select
                value={buzzDuration}
                onChange={(e) => setBuzzDuration(parseInt(e.target.value))}
                className="duration-select"
              >
                <option value={3}>3 sec</option>
                <option value={5}>5 sec</option>
                <option value={10}>10 sec</option>
                <option value={15}>15 sec</option>
              </select>
            </div>
          </div>
        </div>
      )}

      {/* Broadcast Messaging */}
      <div className="control-section">
        <h3>📢 Broadcast Message</h3>
        <div className="broadcast-controls">
          <div className="device-selection-container">
            <div className="device-search-header">
              <input
                type="text"
                placeholder="🔍 Search devices by name or inventory code..."
                value={deviceSearchQuery}
                onChange={(e) => setDeviceSearchQuery(e.target.value)}
                className="device-search-input"
              />
              <button
                type="button"
                onClick={handleSelectAll}
                className="select-all-btn"
              >
                {selectedBroadcastDevices.length === filteredDevices.length && filteredDevices.length > 0
                  ? 'Deselect All'
                  : 'Select All'}
              </button>
            </div>
            <div className="device-list-container">
              {filteredDevices.length === 0 ? (
                <p className="no-devices">No devices found</p>
              ) : (
                <div className="device-checkbox-list">
                  {filteredDevices.map(device => (
                    <label key={device.hostname} className="device-checkbox-item">
                      <input
                        type="checkbox"
                        checked={selectedBroadcastDevices.includes(device.hostname)}
                        onChange={() => handleDeviceToggle(device.hostname)}
                      />
                      <span>
                        {device.hostname}
                        {device.device_inventory_code && ` (${device.device_inventory_code})`}
                      </span>
                    </label>
                  ))}
                </div>
              )}
            </div>
            {selectedBroadcastDevices.length > 0 && (
              <div className="selected-count">
                {selectedBroadcastDevices.length} device(s) selected
              </div>
            )}
          </div>

          <textarea
            value={broadcastMessage}
            onChange={(e) => setBroadcastMessage(e.target.value)}
            placeholder="Enter your message..."
            rows={4}
            className="message-input"
          />
          <button
            onClick={sendBroadcastMessage}
            disabled={loading || !broadcastMessage.trim() || selectedBroadcastDevices.length === 0}
            className="send-broadcast-btn"
          >
            📤 Send Broadcast ({selectedBroadcastDevices.length} device{selectedBroadcastDevices.length !== 1 ? 's' : ''})
          </button>
        </div>
      </div>

      {/* Command History */}
      {targetDevice && (
        <div className="control-section">
          <h3>📜 Command History</h3>
          <div className="command-history">
            {commandHistory.length === 0 ? (
              <p>No commands sent yet for device: {targetDevice}</p>
            ) : (
              <table className="history-table">
                <thead>
                  <tr>
                    <th>Command</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Executed</th>
                    <th>Error</th>
                  </tr>
                </thead>
                <tbody>
                  {commandHistory.map(cmd => (
                    <tr key={cmd.id}>
                      <td>
                        {cmd.command_type}
                        {cmd.duration && ` (${cmd.duration}s)`}
                        {cmd.message && `: ${cmd.message.substring(0, 50)}...`}
                      </td>
                      <td>
                        <span className={`status-badge status-${cmd.status}`}>
                          {cmd.status}
                        </span>
                      </td>
                      <td>{new Date(cmd.created_at).toLocaleString()}</td>
                      <td>{cmd.executed_at ? new Date(cmd.executed_at).toLocaleString() : '-'}</td>
                      <td>{cmd.error_message || '-'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
