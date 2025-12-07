import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './BlocklistManager.css'

interface SoftwareBlocklistItem {
  id: string
  name_pattern: string
  path_pattern: string | null
  is_active: boolean
  created_at: string
}

export default function SoftwareBlocklist() {
  const [blocklist, setBlocklist] = useState<SoftwareBlocklistItem[]>([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [newPath, setNewPath] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)

  useEffect(() => {
    fetchBlocklist()
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('software-blocklist')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'software_blocklist' },
        () => fetchBlocklist()
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  async function fetchBlocklist() {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('software_blocklist')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) throw error
      setBlocklist(data || [])
    } catch (error) {
      console.error('Error fetching blocklist:', error)
    } finally {
      setLoading(false)
    }
  }

  async function addSoftware() {
    if (!newName.trim()) return

    try {
      const { error } = await supabase
        .from('software_blocklist')
        .insert({
          name_pattern: newName.trim(),
          path_pattern: newPath.trim() || null,
          is_active: true
        })

      if (error) throw error
      setNewName('')
      setNewPath('')
      fetchBlocklist()
    } catch (error) {
      console.error('Error adding software:', error)
      alert('Failed to add software. Make sure you have admin permissions.')
    }
  }

  async function toggleActive(id: string, currentStatus: boolean) {
    try {
      const { error } = await supabase
        .from('software_blocklist')
        .update({ is_active: !currentStatus })
        .eq('id', id)

      if (error) throw error
      fetchBlocklist()
    } catch (error) {
      console.error('Error updating software:', error)
    }
  }

  async function deleteSoftware(id: string) {
    if (!confirm('Are you sure you want to delete this software pattern?')) return

    try {
      const { error } = await supabase
        .from('software_blocklist')
        .delete()
        .eq('id', id)

      if (error) throw error
      fetchBlocklist()
    } catch (error) {
      console.error('Error deleting software:', error)
    }
  }

  if (loading) {
    return <div>Loading blocklist...</div>
  }

  return (
    <div className="blocklist-manager">
      <h2>Software Blocklist Management</h2>
      <p className="description">
        Add software patterns to block installation. Devices will be marked non-compliant if blocked software is detected.
      </p>

      <div className="add-form">
        <div className="form-group">
          <label>Software Name Pattern</label>
          <input
            type="text"
            placeholder="e.g., Instagram.exe, *game*.exe, TikTok"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && addSoftware()}
          />
          <small>Use * for wildcards (e.g., *instagram*, *.exe)</small>
        </div>

        <div className="form-group">
          <label>Install Path Pattern (Optional)</label>
          <input
            type="text"
            placeholder="e.g., C:\\Program Files\\*, *\\AppData\\*"
            value={newPath}
            onChange={(e) => setNewPath(e.target.value)}
          />
          <small>Optional: Restrict to specific installation paths</small>
        </div>

        <button onClick={addSoftware} className="add-btn">
          Add Software
        </button>
      </div>

      <div className="blocklist-table-container">
        <table className="blocklist-table">
          <thead>
            <tr>
              <th>Name Pattern</th>
              <th>Path Pattern</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {blocklist.length === 0 ? (
              <tr>
                <td colSpan={5} className="empty-state">
                  No blocked software. Add one above.
                </td>
              </tr>
            ) : (
              blocklist.map((item) => (
                <tr key={item.id} className={!item.is_active ? 'inactive' : ''}>
                  <td><code>{item.name_pattern}</code></td>
                  <td><code>{item.path_pattern || 'Any'}</code></td>
                  <td>
                    <span className={`status-badge ${item.is_active ? 'active' : 'inactive'}`}>
                      {item.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td>{new Date(item.created_at).toLocaleDateString()}</td>
                  <td>
                    <div className="action-buttons">
                      <button
                        onClick={() => toggleActive(item.id, item.is_active)}
                        className={`toggle-btn ${item.is_active ? 'deactivate' : 'activate'}`}
                      >
                        {item.is_active ? 'Deactivate' : 'Activate'}
                      </button>
                      <button
                        onClick={() => deleteSoftware(item.id)}
                        className="delete-btn"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="info-box">
        <strong>How it works:</strong>
        <ul>
          <li>osquery scans installed programs hourly</li>
          <li>Devices with blocked software are marked non-compliant</li>
          <li>Alerts are generated for admin review</li>
          <li>Consider using Windows Group Policy to prevent installation</li>
        </ul>
      </div>
    </div>
  )
}

