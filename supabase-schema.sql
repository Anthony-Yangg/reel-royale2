-- Reel Royale Database Schema for Supabase
-- Run this in your Supabase SQL Editor to set up the database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================
-- PROFILES TABLE (extends auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL DEFAULT '',
    avatar_url TEXT,
    home_location TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public profiles are viewable by everyone"
    ON profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE USING (auth.uid() = id);

-- Trigger to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, created_at)
    VALUES (NEW.id, '', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- TERRITORIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS territories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    spot_ids TEXT[] DEFAULT '{}',
    image_url TEXT,
    region_name TEXT,
    center_latitude DOUBLE PRECISION,
    center_longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE territories ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Territories are viewable by everyone"
    ON territories FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create territories"
    ON territories FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update territories"
    ON territories FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- SPOTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS spots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    water_type TEXT CHECK (water_type IN ('lake', 'river', 'pond', 'stream', 'reservoir', 'bay', 'ocean', 'pier', 'creek', 'canal')),
    territory_id UUID REFERENCES territories(id) ON DELETE SET NULL,
    current_king_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    current_best_catch_id UUID, -- Will add FK after catches table
    current_best_size DOUBLE PRECISION,
    current_best_unit TEXT,
    image_url TEXT,
    region_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

-- Create spatial index for location queries
CREATE INDEX IF NOT EXISTS spots_location_idx ON spots USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
);

-- Enable RLS
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Spots are viewable by everyone"
    ON spots FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create spots"
    ON spots FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update spots"
    ON spots FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- CATCHES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS catches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    spot_id UUID NOT NULL REFERENCES spots(id) ON DELETE CASCADE,
    photo_url TEXT,
    species TEXT NOT NULL,
    size_value DOUBLE PRECISION NOT NULL,
    size_unit TEXT NOT NULL DEFAULT 'cm',
    visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'friends_only', 'private')),
    hide_exact_location BOOLEAN DEFAULT FALSE,
    notes TEXT,
    weather_snapshot JSONB,
    measured_with_ar BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

-- Add FK to spots for current_best_catch_id
ALTER TABLE spots
    ADD CONSTRAINT spots_current_best_catch_fk
    FOREIGN KEY (current_best_catch_id) REFERENCES catches(id) ON DELETE SET NULL;

-- Indexes
CREATE INDEX IF NOT EXISTS catches_user_id_idx ON catches(user_id);
CREATE INDEX IF NOT EXISTS catches_spot_id_idx ON catches(spot_id);
CREATE INDEX IF NOT EXISTS catches_created_at_idx ON catches(created_at DESC);
CREATE INDEX IF NOT EXISTS catches_visibility_idx ON catches(visibility);

-- Enable RLS
ALTER TABLE catches ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public catches are viewable by everyone"
    ON catches FOR SELECT
    USING (visibility IN ('public', 'friends_only') OR auth.uid() = user_id);

CREATE POLICY "Users can insert their own catches"
    ON catches FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own catches"
    ON catches FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own catches"
    ON catches FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- LIKES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    catch_id UUID NOT NULL REFERENCES catches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(catch_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS likes_catch_id_idx ON likes(catch_id);
CREATE INDEX IF NOT EXISTS likes_user_id_idx ON likes(user_id);

-- Enable RLS
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Likes are viewable by everyone"
    ON likes FOR SELECT USING (true);

CREATE POLICY "Users can insert their own likes"
    ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own likes"
    ON likes FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- REGULATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS regulations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    territory_id UUID REFERENCES territories(id) ON DELETE CASCADE,
    region_name TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    season_start DATE,
    season_end DATE,
    size_limits JSONB,
    bag_limits JSONB,
    special_rules TEXT[],
    license_required BOOLEAN DEFAULT TRUE,
    license_info TEXT,
    source_url TEXT,
    last_updated TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS
ALTER TABLE regulations ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Regulations are viewable by everyone"
    ON regulations FOR SELECT USING (true);

-- ============================================
-- STORAGE BUCKETS
-- ============================================

-- Create storage buckets (run in Supabase Dashboard or via API)
-- avatars: For user profile pictures
-- catch-photos: For catch images
-- spot-images: For spot/location images

-- ============================================
-- FUNCTIONS FOR GAME LOGIC
-- ============================================

-- Function to update king after a new catch
CREATE OR REPLACE FUNCTION update_spot_king()
RETURNS TRIGGER AS $$
DECLARE
    current_best DOUBLE PRECISION;
BEGIN
    -- Only process public catches
    IF NEW.visibility NOT IN ('public', 'friends_only') THEN
        RETURN NEW;
    END IF;

    -- Get current best size for the spot
    SELECT current_best_size INTO current_best
    FROM spots
    WHERE id = NEW.spot_id;

    -- If this catch beats the current best, update the king
    IF current_best IS NULL OR NEW.size_value > current_best THEN
        UPDATE spots
        SET
            current_king_user_id = NEW.user_id,
            current_best_catch_id = NEW.id,
            current_best_size = NEW.size_value,
            current_best_unit = NEW.size_unit,
            updated_at = NOW()
        WHERE id = NEW.spot_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_catch_created
    AFTER INSERT ON catches
    FOR EACH ROW EXECUTE FUNCTION update_spot_king();

-- Function to recalculate king when a catch is deleted
CREATE OR REPLACE FUNCTION recalculate_spot_king()
RETURNS TRIGGER AS $$
DECLARE
    best_catch RECORD;
BEGIN
    -- Find the new best catch for the spot
    SELECT c.id, c.user_id, c.size_value, c.size_unit
    INTO best_catch
    FROM catches c
    WHERE c.spot_id = OLD.spot_id
        AND c.visibility IN ('public', 'friends_only')
        AND c.id != OLD.id
    ORDER BY c.size_value DESC
    LIMIT 1;

    -- Update the spot
    IF best_catch IS NOT NULL THEN
        UPDATE spots
        SET
            current_king_user_id = best_catch.user_id,
            current_best_catch_id = best_catch.id,
            current_best_size = best_catch.size_value,
            current_best_unit = best_catch.size_unit,
            updated_at = NOW()
        WHERE id = OLD.spot_id;
    ELSE
        -- No more catches, clear the king
        UPDATE spots
        SET
            current_king_user_id = NULL,
            current_best_catch_id = NULL,
            current_best_size = NULL,
            current_best_unit = NULL,
            updated_at = NOW()
        WHERE id = OLD.spot_id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_catch_deleted
    AFTER DELETE ON catches
    FOR EACH ROW EXECUTE FUNCTION recalculate_spot_king();

-- ============================================
-- SAMPLE DATA (Optional)
-- ============================================

-- Insert sample territories
INSERT INTO territories (id, name, description, region_name, center_latitude, center_longitude) VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Lake Tahoe Basin', 'The scenic Lake Tahoe region in the Sierra Nevada', 'California/Nevada', 39.0968, -120.0324),
    ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Florida Keys', 'The tropical fishing paradise of the Florida Keys', 'Florida', 24.5551, -81.7800),
    ('c3d4e5f6-a7b8-9012-cdef-123456789012', 'Columbia River', 'The mighty Columbia River salmon runs', 'Oregon/Washington', 45.6387, -121.9347)
ON CONFLICT DO NOTHING;

-- Insert sample spots
INSERT INTO spots (id, name, description, latitude, longitude, water_type, territory_id, region_name) VALUES
    ('d4e5f6a7-b8c9-0123-def0-234567890123', 'Emerald Bay', 'Crystal clear waters of Emerald Bay', 38.9542, -120.1100, 'lake', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Lake Tahoe, CA'),
    ('e5f6a7b8-c9d0-1234-ef01-345678901234', 'Sand Harbor', 'Popular fishing spot with sandy beaches', 39.1987, -119.9308, 'lake', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Lake Tahoe, NV'),
    ('f6a7b8c9-d0e1-2345-f012-456789012345', 'Islamorada Flats', 'World-famous bonefish flats', 24.9243, -80.6278, 'bay', 'b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Florida Keys, FL'),
    ('a7b8c9d0-e1f2-3456-0123-567890123456', 'Key West Harbor', 'Deep sea fishing access point', 24.5551, -81.7800, 'ocean', 'b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Florida Keys, FL'),
    ('b8c9d0e1-f2a3-4567-1234-678901234567', 'Bonneville Dam', 'Prime salmon fishing location', 45.6387, -121.9347, 'river', 'c3d4e5f6-a7b8-9012-cdef-123456789012', 'Columbia River, OR')
ON CONFLICT DO NOTHING;

-- Update territories with spot IDs
UPDATE territories SET spot_ids = ARRAY['d4e5f6a7-b8c9-0123-def0-234567890123', 'e5f6a7b8-c9d0-1234-ef01-345678901234'] WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
UPDATE territories SET spot_ids = ARRAY['f6a7b8c9-d0e1-2345-f012-456789012345', 'a7b8c9d0-e1f2-3456-0123-567890123456'] WHERE id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
UPDATE territories SET spot_ids = ARRAY['b8c9d0e1-f2a3-4567-1234-678901234567'] WHERE id = 'c3d4e5f6-a7b8-9012-cdef-123456789012';

-- Insert sample regulations
INSERT INTO regulations (region_name, title, content, license_required, license_info, special_rules) VALUES
    ('California', 'California Freshwater Fishing Regulations', 'General fishing regulations for California freshwater bodies. Always check current regulations at wildlife.ca.gov before fishing.', true, 'California Sport Fishing License required for all anglers 16 and older.', ARRAY['Barbless hooks required in some areas', 'Catch and release only in designated zones']),
    ('Florida', 'Florida Saltwater Fishing Regulations', 'Regulations for saltwater fishing in Florida waters. Visit myfwc.com for complete and current regulations.', true, 'Florida Saltwater Fishing License required.', ARRAY['Some species require stamps', 'Seasonal closures apply to certain species'])
ON CONFLICT DO NOTHING;

COMMIT;

