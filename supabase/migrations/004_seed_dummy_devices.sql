-- =====================================================
-- Seed 5 Devices with Consistent Data Across All Tables
-- Device IDs will be: 100001, 100002, 100003, 100004, 100005
-- =====================================================

-- Clear existing seed data (optional - remove if you want to keep existing data)
-- DELETE FROM web_activity WHERE device_id IN ('PC-LAB-001', 'PC-LAB-002', 'PC-LAB-003', 'PC-LAB-004', 'PC-LAB-005');
-- DELETE FROM software_inventory WHERE device_id IN ('PC-LAB-001', 'PC-LAB-002', 'PC-LAB-003', 'PC-LAB-004', 'PC-LAB-005');
-- DELETE FROM geofence_alerts WHERE device_id IN ('PC-LAB-001', 'PC-LAB-002', 'PC-LAB-003', 'PC-LAB-004', 'PC-LAB-005');
-- DELETE FROM devices WHERE hostname IN ('PC-LAB-001', 'PC-LAB-002', 'PC-LAB-003', 'PC-LAB-004', 'PC-LAB-005');

-- Note: device_id_seq removed - hostname is now primary key

-- Insert 5 devices (one per location)
-- Note: id and fleet_uuid removed (hostname is now primary key, fleet_uuid removed)
INSERT INTO devices (
    hostname,
    serial_number,
    location_id,
    latitude,
    longitude,
    os_version,
    compliance_status,
    last_seen,
    enrollment_date
) VALUES
-- Device: Pune School
(
    'PC-LAB-001',
    'SN123456789',
    (SELECT id FROM locations WHERE name = 'Pune School 1' LIMIT 1),
    18.5210,
    73.8570,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '5 minutes',
    NOW() - INTERVAL '30 days'
),
-- Device: Mumbai School
(
    'PC-LAB-002',
    'SN234567890',
    (SELECT id FROM locations WHERE name = 'Mumbai School 1' LIMIT 1),
    19.0770,
    72.8780,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '10 minutes',
    NOW() - INTERVAL '25 days'
),
-- Device: Delhi School
(
    'PC-LAB-003',
    'SN345678901',
    (SELECT id FROM locations WHERE name = 'Delhi School 1' LIMIT 1),
    28.6140,
    77.2100,
    '10.0.19045',
    'non_compliant',
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '20 days'
),
-- Device: Bangalore School
(
    'PC-LAB-004',
    'SN456789012',
    (SELECT id FROM locations WHERE name = 'Bangalore School 1' LIMIT 1),
    12.9720,
    77.5950,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '1 minute',
    NOW() - INTERVAL '15 days'
),
-- Device: Hyderabad School
(
    'PC-LAB-005',
    'SN567890123',
    (SELECT id FROM locations WHERE name = 'Hyderabad School 1' LIMIT 1),
    17.3860,
    78.4870,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '30 minutes',
    NOW() - INTERVAL '10 days'
)
ON CONFLICT (id) DO UPDATE SET
    hostname = EXCLUDED.hostname,
    last_seen = EXCLUDED.last_seen;

-- =====================================================
-- Insert Software Inventory (8 software per device = 40 rows total)
-- =====================================================

INSERT INTO software_inventory (device_id, name, version, path, installed_at, detected_at)
VALUES
-- Device PC-LAB-001 software
('PC-LAB-001', 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '90 days', NOW()),
('PC-LAB-001', 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '85 days', NOW()),
('PC-LAB-001', 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '120 days', NOW()),
('PC-LAB-001', 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '60 days', NOW()),
('PC-LAB-001', 'Notepad++', '8.5.9', 'C:\Program Files\Notepad++\notepad++.exe', NOW() - INTERVAL '45 days', NOW()),
('PC-LAB-001', 'Python 3.12', '3.12.1', 'C:\Python312\python.exe', NOW() - INTERVAL '30 days', NOW()),
('PC-LAB-001', 'Visual Studio Code', '1.85.2', 'C:\Users\AppData\Local\Programs\Microsoft VS Code\Code.exe', NOW() - INTERVAL '20 days', NOW()),
('PC-LAB-001', 'Git', '2.42.0', 'C:\Program Files\Git\cmd\git.exe', NOW() - INTERVAL '25 days', NOW()),

-- Device PC-LAB-002 software
('PC-LAB-002', 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '95 days', NOW()),
('PC-LAB-002', 'Mozilla Firefox', '121.0', 'C:\Program Files\Mozilla Firefox\firefox.exe', NOW() - INTERVAL '80 days', NOW()),
('PC-LAB-002', 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '115 days', NOW()),
('PC-LAB-002', 'Adobe Reader', '23.008.20470', 'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe', NOW() - INTERVAL '70 days', NOW()),
('PC-LAB-002', 'Zoom', '5.17.0', 'C:\Users\AppData\Roaming\Zoom\bin\Zoom.exe', NOW() - INTERVAL '40 days', NOW()),
('PC-LAB-002', 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '55 days', NOW()),
('PC-LAB-002', '7-Zip', '23.01', 'C:\Program Files\7-Zip\7z.exe', NOW() - INTERVAL '35 days', NOW()),
('PC-LAB-002', 'Google Earth', '7.3.6', 'C:\Program Files\Google\Google Earth Pro\client\googleearth.exe', NOW() - INTERVAL '50 days', NOW()),

-- Device PC-LAB-003 software
('PC-LAB-003', 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '100 days', NOW()),
('PC-LAB-003', 'Google Chrome', '119.0.6045.199', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '88 days', NOW()),
('PC-LAB-003', 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '125 days', NOW()),
('PC-LAB-003', 'Notepad++', '8.5.9', 'C:\Program Files\Notepad++\notepad++.exe', NOW() - INTERVAL '42 days', NOW()),
('PC-LAB-003', 'WinRAR', '6.24', 'C:\Program Files\WinRAR\WinRAR.exe', NOW() - INTERVAL '65 days', NOW()),
('PC-LAB-003', 'Python 3.11', '3.11.6', 'C:\Python311\python.exe', NOW() - INTERVAL '28 days', NOW()),
('PC-LAB-003', 'Java Runtime', '17.0.9', 'C:\Program Files\Java\jre-17\bin\java.exe', NOW() - INTERVAL '75 days', NOW()),
('PC-LAB-003', 'PuTTY', '0.79', 'C:\Program Files\PuTTY\putty.exe', NOW() - INTERVAL '38 days', NOW()),

-- Device PC-LAB-004 software
('PC-LAB-004', 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '92 days', NOW()),
('PC-LAB-004', 'Mozilla Firefox', '121.0', 'C:\Program Files\Mozilla Firefox\firefox.exe', NOW() - INTERVAL '82 days', NOW()),
('PC-LAB-004', 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '118 days', NOW()),
('PC-LAB-004', 'Visual Studio Code', '1.85.2', 'C:\Users\AppData\Local\Programs\Microsoft VS Code\Code.exe', NOW() - INTERVAL '22 days', NOW()),
('PC-LAB-004', 'Git', '2.42.0', 'C:\Program Files\Git\cmd\git.exe', NOW() - INTERVAL '24 days', NOW()),
('PC-LAB-004', 'Node.js', '20.10.0', 'C:\Program Files\nodejs\node.exe', NOW() - INTERVAL '15 days', NOW()),
('PC-LAB-004', 'Docker Desktop', '4.25.0', 'C:\Program Files\Docker\Docker\Docker Desktop.exe', NOW() - INTERVAL '18 days', NOW()),
('PC-LAB-004', 'PostgreSQL', '16.1', 'C:\Program Files\PostgreSQL\16\bin\psql.exe', NOW() - INTERVAL '12 days', NOW()),

-- Device PC-LAB-005 software
('PC-LAB-005', 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '98 days', NOW()),
('PC-LAB-005', 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '86 days', NOW()),
('PC-LAB-005', 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '122 days', NOW()),
('PC-LAB-005', 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '58 days', NOW()),
('PC-LAB-005', 'Audacity', '3.4.2', 'C:\Program Files\Audacity\audacity.exe', NOW() - INTERVAL '32 days', NOW()),
('PC-LAB-005', 'GIMP', '2.10.36', 'C:\Program Files\GIMP 2\bin\gimp-2.10.exe', NOW() - INTERVAL '28 days', NOW()),
('PC-LAB-005', 'Blender', '4.0.1', 'C:\Program Files\Blender Foundation\Blender 4.0\blender.exe', NOW() - INTERVAL '14 days', NOW()),
('PC-LAB-005', 'HandBrake', '1.7.1', 'C:\Program Files\HandBrake\HandBrake.exe', NOW() - INTERVAL '26 days', NOW())
ON CONFLICT DO NOTHING;

-- =====================================================
-- Insert Web Activity (10 visits per device = 50 rows total)
-- =====================================================

INSERT INTO web_activity (device_id, url, domain, category, timestamp)
VALUES
-- Device PC-LAB-001 web activity
('PC-LAB-001', 'https://www.google.com/search?q=science', 'google.com', 'Search', NOW() - INTERVAL '2 hours'),
('PC-LAB-001', 'https://www.wikipedia.org/wiki/Physics', 'wikipedia.org', 'Education', NOW() - INTERVAL '3 hours'),
('PC-LAB-001', 'https://www.khanacademy.org', 'khanacademy.org', 'Education', NOW() - INTERVAL '5 hours'),
('PC-LAB-001', 'https://github.com/explore', 'github.com', 'Development', NOW() - INTERVAL '1 day'),
('PC-LAB-001', 'https://stackoverflow.com/questions', 'stackoverflow.com', 'Development', NOW() - INTERVAL '1 day'),
('PC-LAB-001', 'https://www.youtube.com/watch?v=example', 'youtube.com', 'Entertainment', NOW() - INTERVAL '2 days'),
('PC-LAB-001', 'https://www.coursera.org', 'coursera.org', 'Education', NOW() - INTERVAL '3 days'),
('PC-LAB-001', 'https://docs.python.org', 'python.org', 'Development', NOW() - INTERVAL '4 days'),
('PC-LAB-001', 'https://www.codecademy.com', 'codecademy.com', 'Education', NOW() - INTERVAL '5 days'),
('PC-LAB-001', 'https://www.w3schools.com', 'w3schools.com', 'Education', NOW() - INTERVAL '6 days'),

-- Device PC-LAB-002 web activity
('PC-LAB-002', 'https://www.google.com/search?q=mathematics', 'google.com', 'Search', NOW() - INTERVAL '1 hour'),
('PC-LAB-002', 'https://www.khanacademy.org/math', 'khanacademy.org', 'Education', NOW() - INTERVAL '4 hours'),
('PC-LAB-002', 'https://www.youtube.com/education', 'youtube.com', 'Education', NOW() - INTERVAL '1 day'),
('PC-LAB-002', 'https://www.coursera.org', 'coursera.org', 'Education', NOW() - INTERVAL '2 days'),
('PC-LAB-002', 'https://www.edx.org', 'edx.org', 'Education', NOW() - INTERVAL '2 days'),
('PC-LAB-002', 'https://www.ted.com', 'ted.com', 'Education', NOW() - INTERVAL '3 days'),
('PC-LAB-002', 'https://www.nationalgeographic.com', 'nationalgeographic.com', 'Education', '2024-01-15 10:30:00'),
('PC-LAB-002', 'https://www.britannica.com', 'britannica.com', 'Education', NOW() - INTERVAL '4 days'),
('PC-LAB-002', 'https://www.scholastic.com', 'scholastic.com', 'Education', NOW() - INTERVAL '5 days'),
('PC-LAB-002', 'https://www.nasa.gov', 'nasa.gov', 'Education', NOW() - INTERVAL '6 days'),

-- Device PC-LAB-003 web activity
('PC-LAB-003', 'https://www.google.com/search?q=history', 'google.com', 'Search', NOW() - INTERVAL '3 hours'),
('PC-LAB-003', 'https://www.youtube.com', 'youtube.com', 'Entertainment', NOW() - INTERVAL '6 hours'),
('PC-LAB-003', 'https://www.facebook.com', 'facebook.com', 'Social', NOW() - INTERVAL '1 day'),
('PC-LAB-003', 'https://www.instagram.com', 'instagram.com', 'Social', NOW() - INTERVAL '1 day'),
('PC-LAB-003', 'https://www.twitter.com', 'twitter.com', 'Social', NOW() - INTERVAL '2 days'),
('PC-LAB-003', 'https://www.netflix.com', 'netflix.com', 'Entertainment', NOW() - INTERVAL '2 days'),
('PC-LAB-003', 'https://www.spotify.com', 'spotify.com', 'Entertainment', NOW() - INTERVAL '3 days'),
('PC-LAB-003', 'https://www.amazon.com', 'amazon.com', 'Shopping', NOW() - INTERVAL '4 days'),
('PC-LAB-003', 'https://www.flipkart.com', 'flipkart.com', 'Shopping', NOW() - INTERVAL '4 days'),
('PC-LAB-003', 'https://www.ebay.com', 'ebay.com', 'Shopping', NOW() - INTERVAL '5 days'),

-- Device PC-LAB-004 web activity
('PC-LAB-004', 'https://www.google.com/search?q=programming', 'google.com', 'Search', NOW() - INTERVAL '30 minutes'),
('PC-LAB-004', 'https://github.com', 'github.com', 'Development', NOW() - INTERVAL '1 hour'),
('PC-LAB-004', 'https://stackoverflow.com', 'stackoverflow.com', 'Development', NOW() - INTERVAL '2 hours'),
('PC-LAB-004', 'https://www.freecodecamp.org', 'freecodecamp.org', 'Education', NOW() - INTERVAL '1 day'),
('PC-LAB-004', 'https://www.udemy.com', 'udemy.com', 'Education', NOW() - INTERVAL '1 day'),
('PC-LAB-004', 'https://docs.microsoft.com', 'microsoft.com', 'Development', NOW() - INTERVAL '2 days'),
('PC-LAB-004', 'https://developer.mozilla.org', 'mozilla.org', 'Development', NOW() - INTERVAL '2 days'),
('PC-LAB-004', 'https://www.jetbrains.com', 'jetbrains.com', 'Development', NOW() - INTERVAL '3 days'),
('PC-LAB-004', 'https://www.docker.com', 'docker.com', 'Development', NOW() - INTERVAL '3 days'),
('PC-LAB-004', 'https://kubernetes.io', 'kubernetes.io', 'Development', NOW() - INTERVAL '4 days'),

-- Device PC-LAB-005 web activity
('PC-LAB-005', 'https://www.google.com/search?q=design', 'google.com', 'Search', NOW() - INTERVAL '1 hour'),
('PC-LAB-005', 'https://www.behance.net', 'behance.net', 'Design', NOW() - INTERVAL '3 hours'),
('PC-LAB-005', 'https://dribbble.com', 'dribbble.com', 'Design', NOW() - INTERVAL '4 hours'),
('PC-LAB-005', 'https://www.figma.com', 'figma.com', 'Design', NOW() - INTERVAL '1 day'),
('PC-LAB-005', 'https://www.canva.com', 'canva.com', 'Design', NOW() - INTERVAL '1 day'),
('PC-LAB-005', 'https://www.adobe.com', 'adobe.com', 'Design', NOW() - INTERVAL '2 days'),
('PC-LAB-005', 'https://www.sketch.com', 'sketch.com', 'Design', NOW() - INTERVAL '2 days'),
('PC-LAB-005', 'https://www.pinterest.com', 'pinterest.com', 'Design', NOW() - INTERVAL '3 days'),
('PC-LAB-005', 'https://www.creativebloq.com', 'creativebloq.com', 'Design', NOW() - INTERVAL '4 days'),
('PC-LAB-005', 'https://www.smashingmagazine.com', 'smashingmagazine.com', 'Design', NOW() - INTERVAL '5 days')
ON CONFLICT DO NOTHING;

-- =====================================================
-- Verify: Check counts
-- =====================================================

-- Run these queries to verify:
-- SELECT COUNT(*) as device_count FROM devices WHERE id BETWEEN 100001 AND 100005;
-- SELECT device_id, COUNT(*) as software_count FROM software_inventory WHERE device_id BETWEEN 100001 AND 100005 GROUP BY device_id;
-- SELECT device_id, COUNT(*) as activity_count FROM web_activity WHERE device_id BETWEEN 100001 AND 100005 GROUP BY device_id;

