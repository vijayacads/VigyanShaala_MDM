import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './DeviceControl.css'

interface Device {
  hostname: string
  device_inventory_code?: string
}

interface DeviceCommand {
  id: string
  device_hostname: string
  command_type: string
  message?: string
  duration?: number
  status: 'pending' | 'completed' | 'failed' | 'dismissed' | 'expired'
  created_at: string
  executed_at?: string
  error_message?: string
}

interface DeviceControlProps {
  selectedDevice: string | null
}

export default function DeviceControl({ selectedDevice }: DeviceControlProps) {
  const [devices, setDevices] = useState<Device[]>([])
  const [selectedDevices, setSelectedDevices] = useState<Set<string>>(new Set())
  const [searchText, setSearchText] = useState('')
  const [buzzDuration, setBuzzDuration] = useState(5)
  const [commandHistory, setCommandHistory] = useState<DeviceCommand[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchDevices()
    // Only fetch history if we have a selected device
    if (selectedDevice) {
      fetchCommandHistory(selectedDevice)
    }
    
    // Refresh command history every 5 seconds if device is selected
    if (selectedDevice) {
      const interval = setInterval(() => fetchCommandHistory(selectedDevice), 5000)
      return () => clearInterval(interval)
    }
  }, [selectedDevice])

  useEffect(() => {
    if (selectedDevice) {
      setSelectedDevices(new Set([selectedDevice]))
    }
  }, [selectedDevice])

  async function fetchDevices() {
    try {
      const { data, error } = await supabase
        .from('devices')
        .select('hostname, device_inventory_code')
        .order('hostname')
      
      if (error) throw error
      setDevices(data || [])
    } catch (error) {
      console.error('Error fetching devices:', error)
    }
  }

  async function fetchCommandHistory(deviceHostname?: string) {
    try {
      // If deviceHostname provided, filter by it; otherwise show all
      let query = supabase
        .from('device_commands')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50)
      
      if (deviceHostname) {
        // Normalize hostname for consistent matching
        const normalizedHostname = deviceHostname.trim().toUpperCase()
        query = query.eq('device_hostname', normalizedHostname)
      }
      
      const { data, error } = await query
      
      if (error) throw error
      setCommandHistory(data || [])
    } catch (error) {
      console.error('Error fetching command history:', error)
      setCommandHistory([])
    }
  }

  async function sendCommand(commandType: string, commandData?: any) {
    if (selectedDevices.size === 0) {
      alert('Please select at least one device')
      return
    }

    setLoading(true)
    try {
      // Normalize hostnames and build commands with correct schema
      const commands = Array.from(selectedDevices).map((hostname: string) => {
        const normalizedHostname = hostname.trim().toUpperCase()
        const command: any = {
          device_hostname: normalizedHostname,
          command_type: commandType,
          status: 'pending'
        }
        
        // Add duration for buzz command
        if (commandType === 'buzz' && commandData?.duration) {
          command.duration = commandData.duration
        }
        
        return command
      })

      const { error } = await supabase
        .from('device_commands')
        .insert(commands)

      if (error) throw error

      // Refresh history
      const firstDevice = Array.from(selectedDevices)[0] as string | undefined
      if (firstDevice) {
        await fetchCommandHistory(firstDevice.trim().toUpperCase())
      }
      alert(`Command sent to ${selectedDevices.size} device(s)`)
    } catch (error) {
      console.error('Error sending command:', error)
      alert('Failed to send command')
    } finally {
      setLoading(false)
    }
  }

  function toggleDevice(hostname: string) {
    const newSelected = new Set(selectedDevices)
    if (newSelected.has(hostname)) {
      newSelected.delete(hostname)
    } else {
      newSelected.add(hostname)
    }
    setSelectedDevices(newSelected)
  }

  function selectAll() {
    const filtered = filteredDevices.map(d => d.hostname)
    if (selectedDevices.size === filtered.length) {
      setSelectedDevices(new Set())
    } else {
      setSelectedDevices(new Set(filtered))
    }
  }

  const filteredDevices = devices.filter(device =>
    device.hostname.toLowerCase().includes(searchText.toLowerCase()) ||
    device.device_inventory_code?.toLowerCase().includes(searchText.toLowerCase())
  )

  function getStatusBadgeClass(status: string) {
    return `status-badge status-${status}`
  }

  function formatCommandType(type: string) {
    return type.charAt(0).toUpperCase() + type.slice(1)
  }

  return (
    <div className="device-control-container">
      <h2>Device Control</h2>

      {/* Device Selection */}
      <div className="control-section">
        <h3>Select Devices</h3>
        <div className="device-selection-container">
          <div className="device-search-header">
            <input
              type="text"
              className="device-search-input"
              placeholder="Search devices..."
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
            />
            <button className="select-all-btn" onClick={selectAll}>
              {selectedDevices.size === filteredDevices.length ? 'Deselect All' : 'Select All'}
            </button>
          </div>
          <div className="device-list-container">
            {filteredDevices.length === 0 ? (
              <div className="no-devices">No devices found</div>
            ) : (
              <div className="device-checkbox-list">
                {filteredDevices.map(device => (
                  <div
                    key={device.hostname}
                    className="device-checkbox-item"
                    onClick={() => toggleDevice(device.hostname)}
                  >
                    <input
                      type="checkbox"
                      checked={selectedDevices.has(device.hostname)}
                      onChange={() => toggleDevice(device.hostname)}
                    />
                    <span>{device.hostname} {device.device_inventory_code && `(${device.device_inventory_code})`}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
          {selectedDevices.size > 0 && (
            <div className="selected-count">
              {selectedDevices.size} device(s) selected
            </div>
          )}
        </div>
      </div>

      {/* Device Commands */}
      <div className="control-section">
        <h3>Device Commands</h3>
        <div className="control-buttons">
          <button
            className="control-btn lock-btn"
            onClick={() => sendCommand('lock')}
            disabled={loading || selectedDevices.size === 0}
          >
            🔒 Lock Device
          </button>
          <button
            className="control-btn unlock-btn"
            onClick={() => sendCommand('unlock')}
            disabled={loading || selectedDevices.size === 0}
          >
            🔓 Unlock Device
          </button>
          <button
            className="control-btn cache-btn"
            onClick={() => sendCommand('clear_cache')}
            disabled={loading || selectedDevices.size === 0}
          >
            🗑️ Clear Cache
          </button>
          <div className="buzz-control">
            <button
              className="control-btn buzz-btn"
              onClick={() => sendCommand('buzz', { duration: buzzDuration })}
              disabled={loading || selectedDevices.size === 0}
            >
              🔊 Buzz Device
            </button>
            <select
              className="duration-select"
              value={buzzDuration}
              onChange={(e) => setBuzzDuration(Number(e.target.value))}
            >
              <option value={1}>1 sec</option>
              <option value={3}>3 sec</option>
              <option value={5}>5 sec</option>
              <option value={10}>10 sec</option>
            </select>
          </div>
        </div>
      </div>

      {/* Command History */}
      <div className="control-section">
        <h3>Command History</h3>
        <div className="command-history">
          {commandHistory.length === 0 ? (
            <p>No commands sent yet</p>
          ) : (
            <table className="history-table">
              <thead>
                <tr>
                  <th>Device</th>
                  <th>Command</th>
                  <th>Status</th>
                  <th>Sent</th>
                  <th>Completed</th>
                </tr>
              </thead>
              <tbody>
                {commandHistory.map(cmd => (
                  <tr key={cmd.id}>
                    <td>{cmd.device_hostname}</td>
                    <td>{formatCommandType(cmd.command_type)}</td>
                    <td>
                      <span className={getStatusBadgeClass(cmd.status)}>
                        {cmd.status}
                      </span>
                    </td>
                    <td>{new Date(cmd.created_at).toLocaleString()}</td>
                    <td>{cmd.executed_at ? new Date(cmd.executed_at).toLocaleString() : '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
