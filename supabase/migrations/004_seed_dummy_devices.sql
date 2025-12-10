-- =====================================================
-- Seed 5 Devices with Consistent Data Across All Tables
-- Device IDs will be: 100001, 100002, 100003, 100004, 100005
-- =====================================================

-- Clear existing seed data (optional - remove if you want to keep existing data)
-- DELETE FROM web_activity WHERE device_id BETWEEN 100001 AND 100005;
-- DELETE FROM software_inventory WHERE device_id BETWEEN 100001 AND 100005;
-- DELETE FROM geofence_alerts WHERE device_id BETWEEN 100001 AND 100005;
-- DELETE FROM devices WHERE id BETWEEN 100001 AND 100005;

-- Reset sequence to start at 100001 (if needed)
-- ALTER SEQUENCE device_id_seq RESTART WITH 100001;

-- Insert 5 devices (one per location)
INSERT INTO devices (
    id,
    hostname,
    serial_number,
    fleet_uuid,
    location_id,
    latitude,
    longitude,
    os_version,
    compliance_status,
    last_seen,
    enrollment_date
) VALUES
-- Device 100001: Pune School
(
    100001,
    'PC-LAB-001',
    'SN123456789',
    'fleet-uuid-001',
    (SELECT id FROM locations WHERE name = 'Pune School 1' LIMIT 1),
    18.5210,
    73.8570,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '5 minutes',
    NOW() - INTERVAL '30 days'
),
-- Device 100002: Mumbai School
(
    100002,
    'PC-LAB-002',
    'SN234567890',
    'fleet-uuid-002',
    (SELECT id FROM locations WHERE name = 'Mumbai School 1' LIMIT 1),
    19.0770,
    72.8780,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '10 minutes',
    NOW() - INTERVAL '25 days'
),
-- Device 100003: Delhi School
(
    100003,
    'PC-LAB-003',
    'SN345678901',
    'fleet-uuid-003',
    (SELECT id FROM locations WHERE name = 'Delhi School 1' LIMIT 1),
    28.6140,
    77.2100,
    '10.0.19045',
    'non_compliant',
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '20 days'
),
-- Device 100004: Bangalore School
(
    100004,
    'PC-LAB-004',
    'SN456789012',
    'fleet-uuid-004',
    (SELECT id FROM locations WHERE name = 'Bangalore School 1' LIMIT 1),
    12.9720,
    77.5950,
    '10.0.19045',
    'compliant',
    NOW() - INTERVAL '1 minute',
    NOW() - INTERVAL '15 days'
),
-- Device 100005: Hyderabad School
(
    100005,
    'PC-LAB-005',
    'SN567890123',
    'fleet-uuid-005',
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
-- Device 100001 software
(100001, 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '90 days', NOW()),
(100001, 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '85 days', NOW()),
(100001, 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '120 days', NOW()),
(100001, 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '60 days', NOW()),
(100001, 'Notepad++', '8.5.9', 'C:\Program Files\Notepad++\notepad++.exe', NOW() - INTERVAL '45 days', NOW()),
(100001, 'Python 3.12', '3.12.1', 'C:\Python312\python.exe', NOW() - INTERVAL '30 days', NOW()),
(100001, 'Visual Studio Code', '1.85.2', 'C:\Users\AppData\Local\Programs\Microsoft VS Code\Code.exe', NOW() - INTERVAL '20 days', NOW()),
(100001, 'Git', '2.42.0', 'C:\Program Files\Git\cmd\git.exe', NOW() - INTERVAL '25 days', NOW()),

-- Device 100002 software
(100002, 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '95 days', NOW()),
(100002, 'Mozilla Firefox', '121.0', 'C:\Program Files\Mozilla Firefox\firefox.exe', NOW() - INTERVAL '80 days', NOW()),
(100002, 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '115 days', NOW()),
(100002, 'Adobe Reader', '23.008.20470', 'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe', NOW() - INTERVAL '70 days', NOW()),
(100002, 'Zoom', '5.17.0', 'C:\Users\AppData\Roaming\Zoom\bin\Zoom.exe', NOW() - INTERVAL '40 days', NOW()),
(100002, 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '55 days', NOW()),
(100002, '7-Zip', '23.01', 'C:\Program Files\7-Zip\7z.exe', NOW() - INTERVAL '35 days', NOW()),
(100002, 'Google Earth', '7.3.6', 'C:\Program Files\Google\Google Earth Pro\client\googleearth.exe', NOW() - INTERVAL '50 days', NOW()),

-- Device 100003 software
(100003, 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '100 days', NOW()),
(100003, 'Google Chrome', '119.0.6045.199', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '88 days', NOW()),
(100003, 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '125 days', NOW()),
(100003, 'Notepad++', '8.5.9', 'C:\Program Files\Notepad++\notepad++.exe', NOW() - INTERVAL '42 days', NOW()),
(100003, 'WinRAR', '6.24', 'C:\Program Files\WinRAR\WinRAR.exe', NOW() - INTERVAL '65 days', NOW()),
(100003, 'Python 3.11', '3.11.6', 'C:\Python311\python.exe', NOW() - INTERVAL '28 days', NOW()),
(100003, 'Java Runtime', '17.0.9', 'C:\Program Files\Java\jre-17\bin\java.exe', NOW() - INTERVAL '75 days', NOW()),
(100003, 'PuTTY', '0.79', 'C:\Program Files\PuTTY\putty.exe', NOW() - INTERVAL '38 days', NOW()),

-- Device 100004 software
(100004, 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '92 days', NOW()),
(100004, 'Mozilla Firefox', '121.0', 'C:\Program Files\Mozilla Firefox\firefox.exe', NOW() - INTERVAL '82 days', NOW()),
(100004, 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '118 days', NOW()),
(100004, 'Visual Studio Code', '1.85.2', 'C:\Users\AppData\Local\Programs\Microsoft VS Code\Code.exe', NOW() - INTERVAL '22 days', NOW()),
(100004, 'Git', '2.42.0', 'C:\Program Files\Git\cmd\git.exe', NOW() - INTERVAL '24 days', NOW()),
(100004, 'Node.js', '20.10.0', 'C:\Program Files\nodejs\node.exe', NOW() - INTERVAL '15 days', NOW()),
(100004, 'Docker Desktop', '4.25.0', 'C:\Program Files\Docker\Docker\Docker Desktop.exe', NOW() - INTERVAL '18 days', NOW()),
(100004, 'PostgreSQL', '16.1', 'C:\Program Files\PostgreSQL\16\bin\psql.exe', NOW() - INTERVAL '12 days', NOW()),

-- Device 100005 software
(100005, 'Microsoft Edge', '120.0.2210.91', 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', NOW() - INTERVAL '98 days', NOW()),
(100005, 'Google Chrome', '120.0.6099.109', 'C:\Program Files\Google\Chrome\Application\chrome.exe', NOW() - INTERVAL '86 days', NOW()),
(100005, 'Microsoft Office', '16.0.17328.20148', 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE', NOW() - INTERVAL '122 days', NOW()),
(100005, 'VLC Media Player', '3.0.20', 'C:\Program Files\VideoLAN\VLC\vlc.exe', NOW() - INTERVAL '58 days', NOW()),
(100005, 'Audacity', '3.4.2', 'C:\Program Files\Audacity\audacity.exe', NOW() - INTERVAL '32 days', NOW()),
(100005, 'GIMP', '2.10.36', 'C:\Program Files\GIMP 2\bin\gimp-2.10.exe', NOW() - INTERVAL '28 days', NOW()),
(100005, 'Blender', '4.0.1', 'C:\Program Files\Blender Foundation\Blender 4.0\blender.exe', NOW() - INTERVAL '14 days', NOW()),
(100005, 'HandBrake', '1.7.1', 'C:\Program Files\HandBrake\HandBrake.exe', NOW() - INTERVAL '26 days', NOW())
ON CONFLICT DO NOTHING;

-- =====================================================
-- Insert Web Activity (10 visits per device = 50 rows total)
-- =====================================================

INSERT INTO web_activity (device_id, url, domain, category, timestamp)
VALUES
-- Device 100001 web activity
(100001, 'https://www.google.com/search?q=science', 'google.com', 'Search', NOW() - INTERVAL '2 hours'),
(100001, 'https://www.wikipedia.org/wiki/Physics', 'wikipedia.org', 'Education', NOW() - INTERVAL '3 hours'),
(100001, 'https://www.khanacademy.org', 'khanacademy.org', 'Education', NOW() - INTERVAL '5 hours'),
(100001, 'https://github.com/explore', 'github.com', 'Development', NOW() - INTERVAL '1 day'),
(100001, 'https://stackoverflow.com/questions', 'stackoverflow.com', 'Development', NOW() - INTERVAL '1 day'),
(100001, 'https://www.youtube.com/watch?v=example', 'youtube.com', 'Entertainment', NOW() - INTERVAL '2 days'),
(100001, 'https://www.coursera.org', 'coursera.org', 'Education', NOW() - INTERVAL '3 days'),
(100001, 'https://docs.python.org', 'python.org', 'Development', NOW() - INTERVAL '4 days'),
(100001, 'https://www.codecademy.com', 'codecademy.com', 'Education', NOW() - INTERVAL '5 days'),
(100001, 'https://www.w3schools.com', 'w3schools.com', 'Education', NOW() - INTERVAL '6 days'),

-- Device 100002 web activity
(100002, 'https://www.google.com/search?q=mathematics', 'google.com', 'Search', NOW() - INTERVAL '1 hour'),
(100002, 'https://www.khanacademy.org/math', 'khanacademy.org', 'Education', NOW() - INTERVAL '4 hours'),
(100002, 'https://www.youtube.com/education', 'youtube.com', 'Education', NOW() - INTERVAL '1 day'),
(100002, 'https://www.coursera.org', 'coursera.org', 'Education', NOW() - INTERVAL '2 days'),
(100002, 'https://www.edx.org', 'edx.org', 'Education', NOW() - INTERVAL '2 days'),
(100002, 'https://www.ted.com', 'ted.com', 'Education', NOW() - INTERVAL '3 days'),
(100002, 'https://www.nationalgeographic.com', 'nationalgeographic.com', 'Education', '2024-01-15 10:30:00'),
(100002, 'https://www.britannica.com', 'britannica.com', 'Education', NOW() - INTERVAL '4 days'),
(100002, 'https://www.scholastic.com', 'scholastic.com', 'Education', NOW() - INTERVAL '5 days'),
(100002, 'https://www.nasa.gov', 'nasa.gov', 'Education', NOW() - INTERVAL '6 days'),

-- Device 100003 web activity
(100003, 'https://www.google.com/search?q=history', 'google.com', 'Search', NOW() - INTERVAL '3 hours'),
(100003, 'https://www.youtube.com', 'youtube.com', 'Entertainment', NOW() - INTERVAL '6 hours'),
(100003, 'https://www.facebook.com', 'facebook.com', 'Social', NOW() - INTERVAL '1 day'),
(100003, 'https://www.instagram.com', 'instagram.com', 'Social', NOW() - INTERVAL '1 day'),
(100003, 'https://www.twitter.com', 'twitter.com', 'Social', NOW() - INTERVAL '2 days'),
(100003, 'https://www.netflix.com', 'netflix.com', 'Entertainment', NOW() - INTERVAL '2 days'),
(100003, 'https://www.spotify.com', 'spotify.com', 'Entertainment', NOW() - INTERVAL '3 days'),
(100003, 'https://www.amazon.com', 'amazon.com', 'Shopping', NOW() - INTERVAL '4 days'),
(100003, 'https://www.flipkart.com', 'flipkart.com', 'Shopping', NOW() - INTERVAL '4 days'),
(100003, 'https://www.ebay.com', 'ebay.com', 'Shopping', NOW() - INTERVAL '5 days'),

-- Device 100004 web activity
(100004, 'https://www.google.com/search?q=programming', 'google.com', 'Search', NOW() - INTERVAL '30 minutes'),
(100004, 'https://github.com', 'github.com', 'Development', NOW() - INTERVAL '1 hour'),
(100004, 'https://stackoverflow.com', 'stackoverflow.com', 'Development', NOW() - INTERVAL '2 hours'),
(100004, 'https://www.freecodecamp.org', 'freecodecamp.org', 'Education', NOW() - INTERVAL '1 day'),
(100004, 'https://www.udemy.com', 'udemy.com', 'Education', NOW() - INTERVAL '1 day'),
(100004, 'https://docs.microsoft.com', 'microsoft.com', 'Development', NOW() - INTERVAL '2 days'),
(100004, 'https://developer.mozilla.org', 'mozilla.org', 'Development', NOW() - INTERVAL '2 days'),
(100004, 'https://www.jetbrains.com', 'jetbrains.com', 'Development', NOW() - INTERVAL '3 days'),
(100004, 'https://www.docker.com', 'docker.com', 'Development', NOW() - INTERVAL '3 days'),
(100004, 'https://kubernetes.io', 'kubernetes.io', 'Development', NOW() - INTERVAL '4 days'),

-- Device 100005 web activity
(100005, 'https://www.google.com/search?q=design', 'google.com', 'Search', NOW() - INTERVAL '1 hour'),
(100005, 'https://www.behance.net', 'behance.net', 'Design', NOW() - INTERVAL '3 hours'),
(100005, 'https://dribbble.com', 'dribbble.com', 'Design', NOW() - INTERVAL '4 hours'),
(100005, 'https://www.figma.com', 'figma.com', 'Design', NOW() - INTERVAL '1 day'),
(100005, 'https://www.canva.com', 'canva.com', 'Design', NOW() - INTERVAL '1 day'),
(100005, 'https://www.adobe.com', 'adobe.com', 'Design', NOW() - INTERVAL '2 days'),
(100005, 'https://www.sketch.com', 'sketch.com', 'Design', NOW() - INTERVAL '2 days'),
(100005, 'https://www.pinterest.com', 'pinterest.com', 'Design', NOW() - INTERVAL '3 days'),
(100005, 'https://www.creativebloq.com', 'creativebloq.com', 'Design', NOW() - INTERVAL '4 days'),
(100005, 'https://www.smashingmagazine.com', 'smashingmagazine.com', 'Design', NOW() - INTERVAL '5 days')
ON CONFLICT DO NOTHING;

-- =====================================================
-- Verify: Check counts
-- =====================================================

-- Run these queries to verify:
-- SELECT COUNT(*) as device_count FROM devices WHERE id BETWEEN 100001 AND 100005;
-- SELECT device_id, COUNT(*) as software_count FROM software_inventory WHERE device_id BETWEEN 100001 AND 100005 GROUP BY device_id;
-- SELECT device_id, COUNT(*) as activity_count FROM web_activity WHERE device_id BETWEEN 100001 AND 100005 GROUP BY device_id;
