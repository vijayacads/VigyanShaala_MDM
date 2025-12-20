-- Geofence Debug Queries
-- Run these queries in Supabase SQL Editor to debug geofence issues
-- Replace 'YOUR_DEVICE_HOSTNAME' with your actual device hostname

-- =====================================================
-- 1. Check if device has location_id assigned
-- =====================================================
SELECT 
    hostname,
    location_id,
    latitude,
    longitude,
    compliance_status,
    last_seen
FROM devices 
WHERE hostname = 'YOUR_DEVICE_HOSTNAME';

-- =====================================================
-- 2. Check location configuration (radius_meters, coordinates)
-- =====================================================
SELECT 
    l.id,
    l.name,
    l.latitude,
    l.longitude,
    l.radius_meters,
    l.is_active,
    COUNT(d.id) as device_count
FROM locations l
LEFT JOIN devices d ON d.location_id = l.id
WHERE l.id = (
    SELECT location_id 
    FROM devices 
    WHERE hostname = 'YOUR_DEVICE_HOSTNAME'
)
GROUP BY l.id, l.name, l.latitude, l.longitude, l.radius_meters, l.is_active;

-- =====================================================
-- 3. Check WiFi mappings for device's location
-- =====================================================
SELECT 
    lwm.wifi_ssid,
    lwm.is_active,
    l.name as location_name
FROM location_wifi_mappings lwm
JOIN locations l ON l.id = lwm.location_id
WHERE lwm.location_id = (
    SELECT location_id 
    FROM devices 
    WHERE hostname = 'YOUR_DEVICE_HOSTNAME'
)
ORDER BY lwm.is_active DESC, lwm.wifi_ssid;

-- =====================================================
-- 4. Check existing geofence alerts for device
-- =====================================================
SELECT 
    ga.id,
    ga.violation_type,
    ga.latitude,
    ga.longitude,
    ga.distance_meters,
    ga.created_at,
    ga.resolved_at,
    l.name as location_name
FROM geofence_alerts ga
JOIN locations l ON l.id = ga.location_id
WHERE ga.device_id = 'YOUR_DEVICE_HOSTNAME'
ORDER BY ga.created_at DESC
LIMIT 10;

-- =====================================================
-- 5. Check unresolved alerts count
-- =====================================================
SELECT 
    COUNT(*) as unresolved_count
FROM geofence_alerts
WHERE device_id = 'YOUR_DEVICE_HOSTNAME'
  AND resolved_at IS NULL;

-- =====================================================
-- 6. List all devices without location_id
-- =====================================================
SELECT 
    hostname,
    location_id,
    last_seen,
    compliance_status
FROM devices
WHERE location_id IS NULL
ORDER BY last_seen DESC NULLS LAST;

-- =====================================================
-- 7. List all locations without radius_meters or with 0 radius
-- =====================================================
SELECT 
    id,
    name,
    latitude,
    longitude,
    radius_meters,
    is_active
FROM locations
WHERE radius_meters IS NULL 
   OR radius_meters = 0
   OR radius_meters < 100;

-- =====================================================
-- 8. Calculate distance between device and location center
-- =====================================================
-- This uses the Haversine formula (same as geofence-alert function)
WITH device_location AS (
    SELECT 
        d.hostname,
        d.latitude as device_lat,
        d.longitude as device_lon,
        l.latitude as location_lat,
        l.longitude as location_lon,
        l.radius_meters,
        l.name as location_name
    FROM devices d
    JOIN locations l ON l.id = d.location_id
    WHERE d.hostname = 'YOUR_DEVICE_HOSTNAME'
)
SELECT 
    hostname,
    location_name,
    device_lat,
    device_lon,
    location_lat,
    location_lon,
    radius_meters,
    -- Haversine formula (distance in meters)
    ROUND(
        6371000 * 2 * ASIN(
            SQRT(
                POWER(SIN(RADIANS((location_lat - device_lat) / 2)), 2) +
                COS(RADIANS(device_lat)) * COS(RADIANS(location_lat)) *
                POWER(SIN(RADIANS((location_lon - device_lon) / 2)), 2)
            )
        )
    ) as distance_meters,
    CASE 
        WHEN ROUND(
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS((location_lat - device_lat) / 2)), 2) +
                    COS(RADIANS(device_lat)) * COS(RADIANS(location_lat)) *
                    POWER(SIN(RADIANS((location_lon - device_lon) / 2)), 2)
                )
            )
        ) > radius_meters THEN 'OUTSIDE'
        ELSE 'INSIDE'
    END as geofence_status
FROM device_location;

-- =====================================================
-- 9. Check recent device data submissions (last 24 hours)
-- =====================================================
SELECT 
    hostname,
    latitude,
    longitude,
    last_seen,
    compliance_status
FROM devices
WHERE hostname = 'YOUR_DEVICE_HOSTNAME'
  AND last_seen > NOW() - INTERVAL '24 hours'
ORDER BY last_seen DESC;

-- =====================================================
-- 10. Fix: Assign location to device (if missing)
-- =====================================================
-- Uncomment and update the location_id:
-- UPDATE devices
-- SET location_id = 'YOUR_LOCATION_UUID_HERE'
-- WHERE hostname = 'YOUR_DEVICE_HOSTNAME';

-- =====================================================
-- 11. Fix: Set radius_meters for location (if missing)
-- =====================================================
-- Uncomment and update:
-- UPDATE locations
-- SET radius_meters = 1000  -- Default: 1000 meters
-- WHERE id = 'YOUR_LOCATION_UUID_HERE'
--   AND (radius_meters IS NULL OR radius_meters = 0);




