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

  useEffect(() => {
    fetchDevices()
    fetchLocations()
    if (selectedDevice) {
      fetchCommandHistory(selectedDevice)
    }
  }, [selectedDevice])

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
      const { data, error } = await supabase
        .from('device_commands')
        .select('*')
        .eq('device_hostname', deviceHostname)
        .order('created_at', { ascending: false })
        .limit(50)
      
      if (error) throw error
      setCommandHistory(data || [])
    } catch (error) {
      console.error('Error fetching command history:', error)
    }
  }

  async function sendCommand(commandType: 'lock' | 'unlock' | 'clear_cache' | 'buzz', deviceHostname: string) {
    if (!deviceHostname) {
      alert('Please select a device')
      return
    }

    if (!confirm(`Are you sure you want to ${commandType} device ${deviceHostname}?`)) {
      return
    }

    setLoading(true)
    try {
      const commandData: any = {
        device_hostname: deviceHostname,
        command_type: commandType,
        status: 'pending'
      }

      if (commandType === 'buzz') {
        commandData.duration = buzzDuration
      }

      const { error } = await supabase
        .from('device_commands')
        .insert([commandData])

      if (error) throw error

      alert(`Command sent successfully! Device will execute ${commandType} command.`)
      if (deviceHostname === selectedDevice) {
        fetchCommandHistory(deviceHostname)
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
      const commands = selectedBroadcastDevices.map(hostname => ({
        device_hostname: hostname,
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
      if (selectedDevice && selectedBroadcastDevices.includes(selectedDevice)) {
        fetchCommandHistory(selectedDevice)
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

  const handleSelectAll = () => {
    if (selectedBroadcastDevices.length === filteredDevices.length) {
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

  const targetDevice = selectedDevice || devices[0]?.hostname

  return (
    <div className="device-control-container">
      <h2>🎮 Device Control & Messaging</h2>

      {/* Device Selection */}
      <div className="control-section">
        <h3>Select Device</h3>
        <select
          value={selectedDevice || ''}
          onChange={(e) => {
            if (e.target.value) {
              fetchCommandHistory(e.target.value)
            }
          }}
          className="device-select"
        >
          <option value="">-- Select Device --</option>
          {devices.map(device => (
            <option key={device.hostname} value={device.hostname}>
              {device.hostname} {device.device_inventory_code ? `(${device.device_inventory_code})` : ''}
            </option>
          ))}
        </select>
      </div>

      {/* Device Control Buttons */}
      {targetDevice && (
        <div className="control-section">
          <h3>Device Controls</h3>
          <div className="control-buttons">
            <button
              onClick={() => sendCommand('lock', targetDevice)}
              disabled={loading}
              className="control-btn lock-btn"
            >
              🔒 Lock Device
            </button>
            <button
              onClick={() => sendCommand('unlock', targetDevice)}
              disabled={loading}
              className="control-btn unlock-btn"
            >
              🔓 Unlock Device
            </button>
            <button
              onClick={() => sendCommand('clear_cache', targetDevice)}
              disabled={loading}
              className="control-btn cache-btn"
            >
              🗑️ Clear Cache
            </button>
            <div className="buzz-control">
              <button
                onClick={() => sendCommand('buzz', targetDevice)}
                disabled={loading}
                className="control-btn buzz-btn"
              >
                🔊 Buzz Device
              </button>
              <select
                value={buzzDuration}
                onChange={(e) => setBuzzDuration(parseInt(e.target.value))}
                className="duration-select"
              >
                <option value={5}>5 seconds</option>
                <option value={10}>10 seconds</option>
                <option value={15}>15 seconds</option>
                <option value={30}>30 seconds</option>
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
              <p>No commands sent yet</p>
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
