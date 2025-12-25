import React, { useState, useEffect, useRef } from 'react'
import { supabase } from '../../supabase.config'
import './ChatSupport.css'

interface ChatMessage {
  id: string
  device_hostname: string
  sender: 'center' | 'device'
  message: string
  timestamp: string
  read_status: boolean
  sender_id?: string
}

export default function ChatSupport() {
  const [activeTab, setActiveTab] = useState<'chat' | 'broadcast'>('chat')
  const [devices, setDevices] = useState<any[]>([])
  const [selectedDevice, setSelectedDevice] = useState<string>('')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const [searchFilter, setSearchFilter] = useState('')
  const messagesEndRef = useRef<HTMLDivElement>(null)
  
  // Broadcast state
  const [selectedDevices, setSelectedDevices] = useState<Set<string>>(new Set())
  const [broadcastMessage, setBroadcastMessage] = useState('')
  const [broadcastSearchText, setBroadcastSearchText] = useState('')

  useEffect(() => {
    fetchDevices()
  }, [])

  useEffect(() => {
    if (selectedDevice) {
      fetchMessages(selectedDevice)
      subscribeToMessages(selectedDevice)
    }
    return () => {
      // Cleanup subscription
    }
  }, [selectedDevice])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  async function fetchDevices() {
    try {
      const { data, error } = await supabase
        .from('devices')
        .select('hostname, device_inventory_code, host_location, host_location_state, program_name')
        .order('hostname')
      
      if (error) throw error
      setDevices(data || [])
      if (data && data.length > 0 && !selectedDevice) {
        setSelectedDevice(data[0].hostname)
      }
    } catch (error) {
      console.error('Error fetching devices:', error)
    }
  }

  async function fetchMessages(deviceHostname: string) {
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('device_hostname', deviceHostname)
        .order('timestamp', { ascending: true })
        .limit(100)
      
      if (error) throw error
      setMessages(data || [])
    } catch (error) {
      console.error('Error fetching messages:', error)
    }
  }

  function subscribeToMessages(deviceHostname: string) {
    const channel = supabase
      .channel(`chat:${deviceHostname}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'chat_messages',
          filter: `device_hostname=eq.${deviceHostname}`
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setMessages(prev => [...prev, payload.new as ChatMessage])
            // Play notification sound for new messages
            try {
              const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwU=');
              audio.volume = 0.3;
              audio.play().catch(() => {});
            } catch {}
            // Mark as read if we sent it
            if (payload.new.sender === 'center') {
              markAsRead(payload.new.id)
            }
          } else if (payload.eventType === 'UPDATE') {
            setMessages(prev =>
              prev.map(msg =>
                msg.id === payload.new.id ? payload.new as ChatMessage : msg
              )
            )
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }

  async function sendMessage() {
    if (!newMessage.trim() || !selectedDevice) return

    setLoading(true)
    try {
      const { error } = await supabase
        .from('chat_messages')
        .insert([{
          device_hostname: selectedDevice,
          sender: 'center',
          message: newMessage.trim()
        }])

      if (error) throw error

      // Play notification sound when sending message
      try {
        const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwU=');
        audio.volume = 0.3;
        audio.play().catch(() => {});
      } catch {}

      setNewMessage('')
    } catch (error: any) {
      console.error('Error sending message:', error)
      alert(`Error: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  async function markAsRead(messageId: string) {
    try {
      await supabase
        .from('chat_messages')
        .update({ read_status: true })
        .eq('id', messageId)
    } catch (error) {
      console.error('Error marking message as read:', error)
    }
  }

  function scrollToBottom() {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  // Broadcast functions
  function toggleDevice(hostname: string) {
    const newSelected = new Set(selectedDevices)
    if (newSelected.has(hostname)) {
      newSelected.delete(hostname)
    } else {
      newSelected.add(hostname)
    }
    setSelectedDevices(newSelected)
  }

  // Filter devices for broadcast based on search
  const filteredDevicesForBroadcast = devices.filter(device => {
    if (!broadcastSearchText) return true
    const filter = broadcastSearchText.toLowerCase()
    return (
      device.hostname?.toLowerCase().includes(filter) ||
      device.device_inventory_code?.toLowerCase().includes(filter) ||
      device.host_location?.toLowerCase().includes(filter)
    )
  })

  function selectAll() {
    const filtered = filteredDevicesForBroadcast.map(d => d.hostname)
    if (selectedDevices.size === filtered.length) {
      setSelectedDevices(new Set())
    } else {
      setSelectedDevices(new Set(filtered))
    }
  }

  async function sendBroadcast() {
    if (selectedDevices.size === 0) {
      alert('Please select at least one device')
      return
    }

    if (!broadcastMessage.trim()) {
      alert('Please enter a message')
      return
    }

    setLoading(true)
    try {
      const commands = Array.from(selectedDevices).map((hostname: string) => {
        const normalizedHostname = hostname.trim().toUpperCase()
        return {
          device_hostname: normalizedHostname,
          command_type: 'broadcast_message',
          message: broadcastMessage.trim(),
          status: 'pending'
        }
      })

      const { error } = await supabase
        .from('device_commands')
        .insert(commands)

      if (error) throw error

      setBroadcastMessage('')
      try {
        const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwUZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2LwU=');
        audio.volume = 0.3;
        audio.play().catch(() => {});
      } catch {}
      alert(`Broadcast sent to ${selectedDevices.size} device(s)`)
    } catch (error: any) {
      console.error('Error sending broadcast:', error)
      alert('Failed to send broadcast')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="chat-support-container">
      <h2>💬 Live Chat & Broadcast</h2>
      
      {/* Tabs */}
      <div className="chat-tabs">
        <button
          className={`chat-tab ${activeTab === 'chat' ? 'active' : ''}`}
          onClick={() => setActiveTab('chat')}
        >
          💬 Live Chat
        </button>
        <button
          className={`chat-tab ${activeTab === 'broadcast' ? 'active' : ''}`}
          onClick={() => setActiveTab('broadcast')}
        >
          📢 Broadcast Message
        </button>
      </div>

      {activeTab === 'chat' ? (
        <div className="chat-layout">
          {/* Device Selection Sidebar */}
          <div className="chat-sidebar">
            <h3>Devices</h3>
            <input
              type="text"
              placeholder="Search by name, ID, location, state, program..."
              value={searchFilter}
              onChange={(e) => setSearchFilter(e.target.value)}
              className="device-search-filter"
              style={{
                width: '100%',
                padding: '8px',
                marginBottom: '10px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
            <div className="device-list">
              {devices.filter(device => {
                if (!searchFilter) return true
                const filter = searchFilter.toLowerCase()
                return (
                  device.hostname?.toLowerCase().includes(filter) ||
                  device.device_inventory_code?.toLowerCase().includes(filter) ||
                  device.host_location?.toLowerCase().includes(filter) ||
                  device.host_location_state?.toLowerCase().includes(filter) ||
                  device.program_name?.toLowerCase().includes(filter)
                )
              }).map(device => (
                <div
                  key={device.hostname}
                  className={`device-item ${selectedDevice === device.hostname ? 'active' : ''}`}
                  onClick={() => setSelectedDevice(device.hostname)}
                >
                  <div className="device-name">{device.hostname}</div>
                  {device.device_inventory_code && (
                    <div className="device-code">{device.device_inventory_code}</div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Chat Area */}
          <div className="chat-main">
            {selectedDevice ? (
              <>
                <div className="chat-header">
                  <h3>Chat with {selectedDevice}</h3>
                </div>

                <div className="chat-messages">
                  {messages.map(msg => (
                    <div
                      key={msg.id}
                      className={`message ${msg.sender === 'center' ? 'message-sent' : 'message-received'}`}
                    >
                      <div className="message-content">{msg.message}</div>
                      <div className="message-time">
                        {new Date(msg.timestamp).toLocaleTimeString()}
                      </div>
                    </div>
                  ))}
                  <div ref={messagesEndRef} />
                </div>

                <div className="chat-input-area">
                  <textarea
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="Type your message... (Press Enter to send)"
                    rows={3}
                    className="chat-input"
                  />
                  <button
                    onClick={sendMessage}
                    disabled={loading || !newMessage.trim()}
                    className="send-button"
                  >
                    📤 Send
                  </button>
                </div>
              </>
            ) : (
              <div className="no-device-selected">
                <p>Select a device to start chatting</p>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="broadcast-layout">
          {/* Device Selection */}
          <div className="broadcast-sidebar">
            <h3>Select Devices</h3>
            <div className="broadcast-search-header">
              <input
                type="text"
                className="broadcast-search-input"
                placeholder="Search devices..."
                value={broadcastSearchText}
                onChange={(e) => setBroadcastSearchText(e.target.value)}
              />
              <button className="select-all-btn" onClick={selectAll}>
                {selectedDevices.size === filteredDevicesForBroadcast.length ? 'Deselect All' : 'Select All'}
              </button>
            </div>
            <div className="broadcast-device-list">
              {filteredDevicesForBroadcast.length === 0 ? (
                <div className="no-devices">No devices found</div>
              ) : (
                filteredDevicesForBroadcast.map(device => (
                  <div
                    key={device.hostname}
                    className="broadcast-device-item"
                    onClick={() => toggleDevice(device.hostname)}
                  >
                    <input
                      type="checkbox"
                      checked={selectedDevices.has(device.hostname)}
                      onChange={() => toggleDevice(device.hostname)}
                    />
                    <span>{device.hostname} {device.device_inventory_code && `(${device.device_inventory_code})`}</span>
                  </div>
                ))
              )}
            </div>
            {selectedDevices.size > 0 && (
              <div className="selected-count">
                {selectedDevices.size} device(s) selected
              </div>
            )}
          </div>

          {/* Broadcast Message Area */}
          <div className="broadcast-main">
            <div className="broadcast-header">
              <h3>📢 Broadcast Message</h3>
            </div>
            <div className="broadcast-content">
              <textarea
                className="broadcast-message-input"
                rows={8}
                placeholder="Enter message to broadcast to selected devices..."
                value={broadcastMessage}
                onChange={(e) => setBroadcastMessage(e.target.value)}
              />
              <button
                className="send-broadcast-button"
                onClick={sendBroadcast}
                disabled={loading || selectedDevices.size === 0 || !broadcastMessage.trim()}
              >
                📢 Send Broadcast to {selectedDevices.size} Device(s)
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
