import React from 'react'
import './DeviceDownloads.css'

export default function DeviceDownloads() {
  const handleDownload = async (platform: 'windows' | 'android') => {
    try {
      let fileName = ''
      let filePath = ''
      
      if (platform === 'windows') {
        fileName = 'VigyanShaala-MDM-Installer.zip'
        // In production, this would be served from your backend/CDN
        // For now, using a relative path - adjust based on your deployment
        filePath = '/downloads/VigyanShaala-MDM-Installer.zip'
        
        // Create download link
        const link = document.createElement('a')
        link.href = filePath
        link.download = fileName
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        
        alert(`Download started: ${fileName}\n\nAfter download:\n1. Extract the ZIP file\n2. Run INSTALL.bat as Administrator\n3. Follow the enrollment wizard`)
      } else if (platform === 'android') {
        fileName = 'VigyanShaala-MDM-Android.zip'
        filePath = '/downloads/VigyanShaala-MDM-Android.zip'
        
        const link = document.createElement('a')
        link.href = filePath
        link.download = fileName
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        
        alert(`Download started: ${fileName}\n\nAfter download:\n1. Extract the ZIP file on a computer\n2. Transfer APK to Android device\n3. Enable "Unknown Sources" in Android settings\n4. Install the APK\n5. Complete enrollment in the app`)
      }
    } catch (error) {
      console.error('Download error:', error)
      alert('Download failed. Please try again or contact administrator.')
    }
  }

  return (
    <div className="device-downloads-container">
      <h2>📥 Device Software Downloads</h2>
      <p className="downloads-description">
        Download the MDM installer package for your device platform. 
        The installer includes device enrollment, website blocking, and software blocking features.
      </p>

      <div className="download-buttons">
        <div className="download-card">
          <div className="platform-icon">🪟</div>
          <h3>Windows Installer</h3>
          <p className="platform-description">
            For Windows laptops and computers<br/>
            Includes osquery agent, website blocking, and software blocking
          </p>
          <button 
            className="download-btn windows-btn"
            onClick={() => handleDownload('windows')}
          >
            📦 Download Windows Package
          </button>
          <div className="download-info">
            <strong>File:</strong> VigyanShaala-MDM-Installer.zip<br/>
            <strong>Size:</strong> ~50 MB<br/>
            <strong>Requirements:</strong> Windows 10/11, Administrator privileges
          </div>
        </div>

        <div className="download-card">
          <div className="platform-icon">🤖</div>
          <h3>Android Installer</h3>
          <p className="platform-description">
            For Android tablets and phones<br/>
            Includes device enrollment, website blocking, and app blocking
          </p>
          <button 
            className="download-btn android-btn"
            onClick={() => handleDownload('android')}
          >
            📦 Download Android Package
          </button>
          <div className="download-info">
            <strong>File:</strong> VigyanShaala-MDM-Android.zip<br/>
            <strong>Size:</strong> ~10 MB<br/>
            <strong>Requirements:</strong> Android 8.0+, Device Admin permissions
          </div>
        </div>
      </div>

      <div className="installation-instructions">
        <h3>Installation Instructions</h3>
        <div className="instructions-grid">
          <div className="instruction-section">
            <h4>Windows</h4>
            <ol>
              <li>Download and extract the ZIP file</li>
              <li>Right-click <code>INSTALL.bat</code> and select "Run as Administrator"</li>
              <li>Follow the enrollment wizard to register your device</li>
              <li>Website and software blocking will activate automatically</li>
            </ol>
          </div>
          <div className="instruction-section">
            <h4>Android</h4>
            <ol>
              <li>Download and extract the ZIP file on a computer</li>
              <li>Transfer the APK file to your Android device</li>
              <li>Enable "Install from Unknown Sources" in Android settings</li>
              <li>Install the APK and complete enrollment</li>
              <li>Grant Device Admin permissions when prompted</li>
            </ol>
          </div>
        </div>
      </div>

      <div className="features-info">
        <h3>Included Features</h3>
        <ul>
          <li>✅ Device enrollment and registration</li>
          <li>✅ Website blocking (all browsers)</li>
          <li>✅ Software/App blocking</li>
          <li>✅ Automatic policy sync</li>
          <li>✅ Device monitoring and reporting</li>
        </ul>
      </div>
    </div>
  )
}

