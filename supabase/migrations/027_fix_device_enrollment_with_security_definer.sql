-- Migration 027: Fix device enrollment using SECURITY DEFINER function
-- Per learnings: Use SECURITY DEFINER functions from Day 1 to bypass RLS evaluation issues
-- This solves PostgREST policy evaluation problems that prevent device enrollment
-- NOTE: devices table uses hostname as primary key (not id) - migration 008

-- =====================================================
-- 1. Create SECURITY DEFINER function for device enrollment
-- =====================================================

CREATE OR REPLACE FUNCTION public.enroll_device(
    p_hostname TEXT,
    p_device_inventory_code TEXT DEFAULT NULL,
    p_device_imei_number TEXT DEFAULT NULL,
    p_device_make TEXT DEFAULT NULL,
    p_host_location TEXT DEFAULT NULL,
    p_city_town_village TEXT DEFAULT NULL,
    p_laptop_model TEXT DEFAULT NULL,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_os_version TEXT DEFAULT NULL,
    p_assigned_teacher TEXT DEFAULT NULL,
    p_assigned_student_leader TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_issue_date DATE DEFAULT NULL,
    p_wifi_ssid TEXT DEFAULT NULL,
    p_compliance_status TEXT DEFAULT 'unknown',
    p_last_seen TIMESTAMPTZ DEFAULT NOW(),
    p_location_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Bypasses RLS - runs with function owner's privileges
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Insert device (bypasses RLS due to SECURITY DEFINER)
    -- hostname is the primary key (migration 008)
    INSERT INTO devices (
        hostname,
        device_inventory_code,
        device_imei_number,
        device_make,
        host_location,
        city_town_village,
        laptop_model,
        latitude,
        longitude,
        os_version,
        assigned_teacher,
        assigned_student_leader,
        role,
        issue_date,
        wifi_ssid,
        compliance_status,
        last_seen,
        location_id
    ) VALUES (
        p_hostname,
        p_device_inventory_code,
        p_device_imei_number,
        p_device_make,
        p_host_location,
        p_city_town_village,
        p_laptop_model,
        p_latitude,
        p_longitude,
        p_os_version,
        p_assigned_teacher,
        p_assigned_student_leader,
        p_role,
        p_issue_date,
        p_wifi_ssid,
        p_compliance_status,
        p_last_seen,
        p_location_id
    );
    
    -- Return the inserted device as JSONB (using hostname as key)
    SELECT to_jsonb(d.*) INTO v_result
    FROM devices d
    WHERE d.hostname = p_hostname;
    
    RETURN v_result;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Device with hostname % already exists', p_hostname;
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid location_id provided';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Enrollment failed: %', SQLERRM;
END;
$$;

-- =====================================================
-- 2. Grant execute permission to anon and authenticated
-- =====================================================

GRANT EXECUTE ON FUNCTION public.enroll_device TO anon, authenticated;

-- =====================================================
-- 3. Test the function (optional - can be removed after verification)
-- =====================================================

-- Test as anon (simulates PowerShell)
DO $$
DECLARE
    result JSONB;
    test_hostname TEXT := 'TEST-FN-' || substring(gen_random_uuid()::text, 1, 8);
BEGIN
    SET LOCAL ROLE anon;
    
    SELECT public.enroll_device(
        p_hostname := test_hostname,
        p_compliance_status := 'unknown'
    ) INTO result;
    
    RAISE NOTICE 'Function test successful. Device: %', result->>'hostname';
    
    -- Cleanup test device
    DELETE FROM devices WHERE hostname = test_hostname;
    
    RESET ROLE;
EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    RAISE EXCEPTION 'Function test failed: %', SQLERRM;
END $$;

