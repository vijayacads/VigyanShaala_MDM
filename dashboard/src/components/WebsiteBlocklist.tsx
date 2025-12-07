import { useState, useEffect } from 'react'
import { supabase } from '../../supabase.config'
import './BlocklistManager.css'

interface WebsiteBlocklistItem {
  id: string
  domain_pattern: string
  category: string
  is_active: boolean
  created_at: string
}

export default function WebsiteBlocklist() {
  const [blocklist, setBlocklist] = useState<WebsiteBlocklistItem[]>([])
  const [loading, setLoading] = useState(true)
  const [newDomain, setNewDomain] = useState('')
  const [newCategory, setNewCategory] = useState('social_media')
  const [editingId, setEditingId] = useState<string | null>(null)

  useEffect(() => {
    fetchBlocklist()
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('website-blocklist')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'website_blocklist' },
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
        .from('website_blocklist')
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

  async function addDomain() {
    if (!newDomain.trim()) return

    try {
      const { error } = await supabase
        .from('website_blocklist')
        .insert({
          domain_pattern: newDomain.trim(),
          category: newCategory,
          is_active: true
        })

      if (error) throw error
      setNewDomain('')
      fetchBlocklist()
    } catch (error) {
      console.error('Error adding domain:', error)
      alert('Failed to add domain. Make sure you have admin permissions.')
    }
  }

  async function toggleActive(id: string, currentStatus: boolean) {
    try {
      const { error } = await supabase
        .from('website_blocklist')
        .update({ is_active: !currentStatus })
        .eq('id', id)

      if (error) throw error
      fetchBlocklist()
    } catch (error) {
      console.error('Error updating domain:', error)
    }
  }

  async function deleteDomain(id: string) {
    if (!confirm('Are you sure you want to delete this domain?')) return

    try {
      const { error } = await supabase
        .from('website_blocklist')
        .delete()
        .eq('id', id)

      if (error) throw error
      fetchBlocklist()
    } catch (error) {
      console.error('Error deleting domain:', error)
    }
  }

  if (loading) {
    return <div>Loading blocklist...</div>
  }

  return (
    <div className="blocklist-manager">
      <h2>Website Blocklist Management</h2>
      <p className="description">
        Add domains to block centrally. Changes apply to all devices via Chrome policy.
      </p>

      <div className="add-form">
        <div className="form-group">
          <label>Domain Pattern</label>
          <input
            type="text"
            placeholder="e.g., facebook.com, instagram.com, *.tiktok.com"
            value={newDomain}
            onChange={(e) => setNewDomain(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && addDomain()}
          />
          <small>Use * for wildcards (e.g., *.facebook.com)</small>
        </div>

        <div className="form-group">
          <label>Category</label>
          <select
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value)}
          >
            <option value="social_media">Social Media</option>
            <option value="gaming">Gaming</option>
            <option value="entertainment">Entertainment</option>
            <option value="shopping">Shopping</option>
            <option value="other">Other</option>
          </select>
        </div>

        <button onClick={addDomain} className="add-btn">
          Add Domain
        </button>
      </div>

      <div className="blocklist-table-container">
        <table className="blocklist-table">
          <thead>
            <tr>
              <th>Domain Pattern</th>
              <th>Category</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {blocklist.length === 0 ? (
              <tr>
                <td colSpan={5} className="empty-state">
                  No blocked domains. Add one above.
                </td>
              </tr>
            ) : (
              blocklist.map((item) => (
                <tr key={item.id} className={!item.is_active ? 'inactive' : ''}>
                  <td><code>{item.domain_pattern}</code></td>
                  <td>
                    <span className="category-badge">{item.category}</span>
                  </td>
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
                        onClick={() => deleteDomain(item.id)}
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
          <li>Domains are synced to devices via Chrome policy</li>
          <li>Blocked domains are automatically enforced on all enrolled devices</li>
          <li>Changes take effect within 5-10 minutes</li>
          <li>Download Chrome policy JSON from: <code>/functions/v1/blocklist-sync</code></li>
        </ul>
      </div>

      <div className="policy-download">
        <button
          onClick={async () => {
            try {
              const { data } = await supabase.functions.invoke('blocklist-sync')
              const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
              const url = URL.createObjectURL(blob)
              const a = document.createElement('a')
              a.href = url
              a.download = 'chrome-policy.json'
              a.click()
              URL.revokeObjectURL(url)
            } catch (error) {
              alert('Failed to download policy. Make sure Edge Function is deployed.')
            }
          }}
          className="download-btn"
        >
          Download Chrome Policy JSON
        </button>
      </div>
    </div>
  )
}

