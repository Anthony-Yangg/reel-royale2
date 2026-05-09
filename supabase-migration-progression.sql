-- Reel Royale: Progression System Migration
-- Adds XP, Lure Coins, Ranks, Tackle Shop, Challenges, Seasons, Codex, Notifications
-- Run AFTER supabase-schema.sql in Supabase SQL Editor.
-- Idempotent: safe to re-run.

-- ============================================
-- PROFILES: Add progression columns
-- ============================================
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS xp INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rank_tier TEXT NOT NULL DEFAULT 'Minnow',
    ADD COLUMN IF NOT EXISTS lure_coins INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS season_score INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS equipped_rod_skin_id UUID,
    ADD COLUMN IF NOT EXISTS equipped_badge_id UUID,
    ADD COLUMN IF NOT EXISTS equipped_flag_id UUID,
    ADD COLUMN IF NOT EXISTS equipped_frame_id UUID,
    ADD COLUMN IF NOT EXISTS push_token TEXT;

-- Index for leaderboards
CREATE INDEX IF NOT EXISTS profiles_xp_idx ON profiles(xp DESC);
CREATE INDEX IF NOT EXISTS profiles_season_score_idx ON profiles(season_score DESC);

-- ============================================
-- CATCHES: Add progression metadata
-- ============================================
ALTER TABLE catches
    ADD COLUMN IF NOT EXISTS xp_awarded INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coins_awarded INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS released BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS species_id UUID,
    ADD COLUMN IF NOT EXISTS dethroned_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS season_id UUID;

-- ============================================
-- SPOTS: Add streak tracking
-- ============================================
ALTER TABLE spots
    ADD COLUMN IF NOT EXISTS king_since TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_catch_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS total_catches INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS unique_anglers INTEGER NOT NULL DEFAULT 0;

-- ============================================
-- SPECIES (Codex)
-- ============================================
CREATE TABLE IF NOT EXISTS species (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    common_name TEXT,
    rarity_tier TEXT NOT NULL CHECK (rarity_tier IN ('common', 'uncommon', 'rare', 'trophy')),
    xp_multiplier NUMERIC NOT NULL DEFAULT 1.0,
    description TEXT,
    habitat TEXT,
    average_size NUMERIC,
    family TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE species ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Species are viewable by everyone"
    ON species FOR SELECT USING (true);

-- Now add FK from catches.species_id
ALTER TABLE catches
    DROP CONSTRAINT IF EXISTS catches_species_id_fk;
ALTER TABLE catches
    ADD CONSTRAINT catches_species_id_fk
    FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE SET NULL;

-- Seed species (matches CommonFishSpecies enum + rarity tiers)
INSERT INTO species (name, common_name, rarity_tier, xp_multiplier, family) VALUES
    ('Bluegill', 'Bluegill', 'common', 1.0, 'Centrarchidae'),
    ('Yellow Perch', 'Perch', 'common', 1.0, 'Percidae'),
    ('Crappie', 'Crappie', 'common', 1.0, 'Centrarchidae'),
    ('Common Carp', 'Carp', 'common', 1.0, 'Cyprinidae'),
    ('Channel Catfish', 'Channel Catfish', 'common', 1.0, 'Ictaluridae'),
    ('Largemouth Bass', 'Largemouth Bass', 'uncommon', 1.5, 'Centrarchidae'),
    ('Smallmouth Bass', 'Smallmouth Bass', 'uncommon', 1.5, 'Centrarchidae'),
    ('Rainbow Trout', 'Rainbow Trout', 'uncommon', 1.5, 'Salmonidae'),
    ('Brown Trout', 'Brown Trout', 'uncommon', 1.5, 'Salmonidae'),
    ('Brook Trout', 'Brook Trout', 'uncommon', 1.5, 'Salmonidae'),
    ('Walleye', 'Walleye', 'uncommon', 1.5, 'Percidae'),
    ('Flounder', 'Flounder', 'uncommon', 1.5, 'Pleuronectidae'),
    ('Striped Bass', 'Striped Bass', 'rare', 2.5, 'Moronidae'),
    ('Northern Pike', 'Northern Pike', 'rare', 2.5, 'Esocidae'),
    ('Salmon', 'Salmon', 'rare', 2.5, 'Salmonidae'),
    ('Steelhead', 'Steelhead', 'rare', 2.5, 'Salmonidae'),
    ('Redfish', 'Redfish', 'rare', 2.5, 'Sciaenidae'),
    ('Snook', 'Snook', 'rare', 2.5, 'Centropomidae'),
    ('Bonefish', 'Bonefish', 'rare', 2.5, 'Albulidae'),
    ('Halibut', 'Halibut', 'rare', 2.5, 'Pleuronectidae'),
    ('Muskellunge', 'Musky', 'trophy', 5.0, 'Esocidae'),
    ('Tarpon', 'Tarpon', 'trophy', 5.0, 'Megalopidae'),
    ('Other', 'Other', 'common', 1.0, NULL)
ON CONFLICT (name) DO UPDATE SET
    rarity_tier = EXCLUDED.rarity_tier,
    xp_multiplier = EXCLUDED.xp_multiplier,
    family = EXCLUDED.family;

-- ============================================
-- USER_SPECIES (per-user codex)
-- ============================================
CREATE TABLE IF NOT EXISTS user_species (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
    personal_best_size NUMERIC,
    personal_best_unit TEXT,
    personal_best_catch_id UUID REFERENCES catches(id) ON DELETE SET NULL,
    total_caught INTEGER NOT NULL DEFAULT 1,
    first_caught_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    first_caught_spot_id UUID REFERENCES spots(id) ON DELETE SET NULL,
    last_caught_at TIMESTAMPTZ,
    UNIQUE(user_id, species_id)
);

CREATE INDEX IF NOT EXISTS user_species_user_id_idx ON user_species(user_id);
CREATE INDEX IF NOT EXISTS user_species_species_id_idx ON user_species(species_id);

ALTER TABLE user_species ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User species rows are publicly viewable"
    ON user_species FOR SELECT USING (true);

CREATE POLICY "Users can write their own user_species"
    ON user_species FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- SEASONS
-- ============================================
CREATE TABLE IF NOT EXISTS seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_number INTEGER UNIQUE NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS seasons_active_idx ON seasons(is_active);

ALTER TABLE seasons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Seasons are viewable by everyone"
    ON seasons FOR SELECT USING (true);

-- Now add FK from catches.season_id
ALTER TABLE catches
    DROP CONSTRAINT IF EXISTS catches_season_id_fk;
ALTER TABLE catches
    ADD CONSTRAINT catches_season_id_fk
    FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE SET NULL;

-- ============================================
-- SEASON CHAMPIONS (permanent hall of fame)
-- ============================================
CREATE TABLE IF NOT EXISTS season_champions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    territory_id UUID REFERENCES territories(id) ON DELETE SET NULL,
    rank INTEGER NOT NULL CHECK (rank > 0),
    season_score INTEGER NOT NULL DEFAULT 0,
    awarded_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(season_id, territory_id, rank)
);

CREATE INDEX IF NOT EXISTS season_champions_user_id_idx ON season_champions(user_id);
CREATE INDEX IF NOT EXISTS season_champions_season_id_idx ON season_champions(season_id);

ALTER TABLE season_champions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Season champions are viewable by everyone"
    ON season_champions FOR SELECT USING (true);

-- ============================================
-- SHOP_ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS shop_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('rod_skin', 'badge', 'flag', 'frame')),
    cost_coins INTEGER NOT NULL CHECK (cost_coins >= 0),
    rank_required TEXT,
    description TEXT,
    icon_name TEXT,
    color_hex TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    requires_release_count INTEGER,
    requires_trophy_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE shop_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shop items are viewable by everyone"
    ON shop_items FOR SELECT USING (true);

-- Seed shop catalog
INSERT INTO shop_items (name, category, cost_coins, rank_required, description, icon_name, sort_order, requires_release_count, requires_trophy_count) VALUES
    ('Bamboo Classic Rod', 'rod_skin', 150, NULL, 'A timeless wooden rod skin', 'tree.fill', 1, NULL, NULL),
    ('Carbon Fiber Rod', 'rod_skin', 200, NULL, 'Lightweight modern carbon finish', 'bolt.fill', 2, NULL, NULL),
    ('Neon Glow Rod', 'rod_skin', 400, NULL, 'Pulsing neon profile flair', 'sparkles', 3, NULL, NULL),
    ('Gold Champion Rod', 'rod_skin', 800, 'Legend', 'Reserved for Legend rank anglers', 'crown.fill', 4, NULL, NULL),
    ('Local Legend', 'badge', 300, NULL, 'Show your home water dominance', 'star.fill', 1, NULL, NULL),
    ('Catch & Release King', 'badge', 250, NULL, 'Unlock at 50 catch-and-release logs', 'arrow.triangle.2.circlepath', 2, 50, NULL),
    ('Trophy Hunter', 'badge', 500, NULL, 'Unlock at 5 trophy-rarity catches', 'trophy.fill', 3, NULL, 5),
    ('Crimson Flag', 'flag', 200, NULL, 'Custom red territory flag', 'flag.fill', 1, NULL, NULL),
    ('Azure Flag', 'flag', 200, NULL, 'Custom blue territory flag', 'flag.fill', 2, NULL, NULL),
    ('Emerald Flag', 'flag', 200, NULL, 'Custom green territory flag', 'flag.fill', 3, NULL, NULL),
    ('Animated Pulse Flag', 'flag', 600, NULL, 'Pulsing animated flag on map', 'flag.2.crossed.fill', 4, NULL, NULL),
    ('Wooden Frame', 'frame', 100, NULL, 'Rustic wood profile frame', 'square.stack.fill', 1, NULL, NULL),
    ('Gold Frame', 'frame', 350, NULL, 'Gilded gold profile frame', 'square.stack.fill', 2, NULL, NULL),
    ('Diamond Frame', 'frame', 700, 'Elite', 'Diamond frame for Elite+ anglers', 'diamond.fill', 3, NULL, NULL)
ON CONFLICT (name) DO UPDATE SET
    cost_coins = EXCLUDED.cost_coins,
    rank_required = EXCLUDED.rank_required,
    description = EXCLUDED.description,
    requires_release_count = EXCLUDED.requires_release_count,
    requires_trophy_count = EXCLUDED.requires_trophy_count;

-- ============================================
-- USER_INVENTORY
-- ============================================
CREATE TABLE IF NOT EXISTS user_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES shop_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(user_id, item_id)
);

CREATE INDEX IF NOT EXISTS user_inventory_user_id_idx ON user_inventory(user_id);
CREATE INDEX IF NOT EXISTS user_inventory_item_id_idx ON user_inventory(item_id);

ALTER TABLE user_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own inventory"
    ON user_inventory FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view equipped items (for display)"
    ON user_inventory FOR SELECT USING (is_equipped = true);

CREATE POLICY "Users can write their own inventory"
    ON user_inventory FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- CHALLENGES (definitions)
-- ============================================
CREATE TABLE IF NOT EXISTS challenges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('daily', 'weekly')),
    xp_reward INTEGER NOT NULL DEFAULT 0,
    coin_reward INTEGER NOT NULL DEFAULT 0,
    condition_type TEXT NOT NULL CHECK (condition_type IN (
        'catch_any',
        'catch_weight_over',
        'catch_before_noon',
        'visit_n_spots',
        'catch_and_release',
        'catch_species_first',
        'become_king',
        'catch_count_in_window',
        'catch_in_n_territories',
        'hold_king_n_days'
    )),
    condition_payload JSONB NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Challenges are viewable by everyone"
    ON challenges FOR SELECT USING (true);

-- Seed daily challenges
INSERT INTO challenges (title, description, type, xp_reward, coin_reward, condition_type, condition_payload) VALUES
    ('Wet a Line', 'Catch any fish today.', 'daily', 50, 5, 'catch_any', '{}'),
    ('Heavyweight', 'Catch a fish over 1kg.', 'daily', 100, 10, 'catch_weight_over', '{"min_kg": 1.0}'),
    ('Early Bird', 'Log a catch before noon.', 'daily', 75, 8, 'catch_before_noon', '{}'),
    ('Spot Hopper', 'Visit 2 different spots today.', 'daily', 120, 12, 'visit_n_spots', '{"count": 2}'),
    ('Conservationist', 'Catch and release a fish.', 'daily', 80, 15, 'catch_and_release', '{}'),
    ('First Blood', 'Log your first catch of any new species today.', 'daily', 150, 20, 'catch_species_first', '{}')
ON CONFLICT DO NOTHING;

-- Seed weekly challenges
INSERT INTO challenges (title, description, type, xp_reward, coin_reward, condition_type, condition_payload) VALUES
    ('King for a Day', 'Become king of any spot this week.', 'weekly', 500, 75, 'become_king', '{}'),
    ('Five Alive', 'Catch 5 fish in one week.', 'weekly', 400, 60, 'catch_count_in_window', '{"count": 5, "window_days": 7}'),
    ('Three Kingdoms', 'Catch fish in 3 different territories.', 'weekly', 600, 90, 'catch_in_n_territories', '{"count": 3}'),
    ('Long Live the King', 'Hold a king title for 3 consecutive days.', 'weekly', 450, 70, 'hold_king_n_days', '{"days": 3}')
ON CONFLICT DO NOTHING;

-- ============================================
-- USER_CHALLENGES (per-user assignment + progress)
-- ============================================
CREATE TABLE IF NOT EXISTS user_challenges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    assigned_date DATE NOT NULL,
    progress JSONB NOT NULL DEFAULT '{}',
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    rewarded BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, challenge_id, assigned_date)
);

CREATE INDEX IF NOT EXISTS user_challenges_user_id_idx ON user_challenges(user_id);
CREATE INDEX IF NOT EXISTS user_challenges_assigned_date_idx ON user_challenges(assigned_date DESC);

ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own challenges"
    ON user_challenges FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can write their own challenges"
    ON user_challenges FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================
-- NOTIFICATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'dethroned',
        'defended',
        'challenge_complete',
        'season_end',
        'rank_up',
        'crown_taken',
        'streak_bonus',
        'new_territory'
    )),
    title TEXT NOT NULL,
    body TEXT,
    payload JSONB,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx ON notifications(user_id) WHERE read = false;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role inserts notifications"
    ON notifications FOR INSERT WITH CHECK (true);

-- ============================================
-- Helper: compute rank tier from XP total (mirror of Swift RankTier)
-- ============================================
CREATE OR REPLACE FUNCTION compute_rank_tier(total_xp INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF total_xp >= 100000 THEN RETURN 'Legend';
    ELSIF total_xp >= 40000 THEN RETURN 'Master';
    ELSIF total_xp >= 15000 THEN RETURN 'Elite';
    ELSIF total_xp >= 5000 THEN RETURN 'Veteran';
    ELSIF total_xp >= 1000 THEN RETURN 'Angler';
    ELSE RETURN 'Minnow';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- BEFORE INSERT trigger: compute reward fields, mutate NEW.
-- This must NOT touch FK-related rows (spots.current_best_catch_id,
-- user_species.personal_best_catch_id, notifications.payload->new_catch_id).
-- The catch row doesn't exist yet, so any UPDATE referencing NEW.id would
-- violate non-deferred FKs.
-- ============================================
CREATE OR REPLACE FUNCTION catch_before_insert_compute()
RETURNS TRIGGER AS $$
DECLARE
    current_best DOUBLE PRECISION;
    previous_king UUID;
    species_row species%ROWTYPE;
    base_xp INTEGER;
    bonus_xp INTEGER := 0;
    species_multiplier NUMERIC;
    is_first_species BOOLEAN := FALSE;
    total_xp INTEGER;
    total_coins INTEGER;
    crown_taken BOOLEAN := FALSE;
    active_season_id UUID;
    weight_kg NUMERIC;
    is_first_catch_today BOOLEAN := FALSE;
    is_first_in_territory BOOLEAN := FALSE;
    has_7day_streak BOOLEAN := FALSE;
    spot_territory UUID;
BEGIN
    IF NEW.visibility NOT IN ('public', 'friends_only') THEN
        RETURN NEW;
    END IF;

    -- Resolve species
    SELECT * INTO species_row FROM species WHERE name ILIKE NEW.species LIMIT 1;
    species_multiplier := COALESCE(species_row.xp_multiplier, 1.0);
    NEW.species_id := COALESCE(NEW.species_id, species_row.id);

    -- Base XP from weight
    IF NEW.size_unit IN ('kg', 'lbs') THEN
        weight_kg := CASE WHEN NEW.size_unit = 'lbs' THEN NEW.size_value * 0.4536 ELSE NEW.size_value END;
        base_xp := GREATEST(10, FLOOR(weight_kg * 100));
    ELSE
        base_xp := 100;
    END IF;

    -- First-of-species bonus
    IF species_row.id IS NOT NULL THEN
        SELECT NOT EXISTS (
            SELECT 1 FROM user_species
            WHERE user_id = NEW.user_id AND species_id = species_row.id
        ) INTO is_first_species;
    END IF;
    IF is_first_species THEN
        bonus_xp := bonus_xp + 100;
    END IF;
    IF NEW.released THEN
        bonus_xp := bonus_xp + 50;
    END IF;

    -- King status (read-only here; AFTER trigger applies the UPDATE)
    SELECT current_best_size, current_king_user_id, territory_id
        INTO current_best, previous_king, spot_territory
    FROM spots WHERE id = NEW.spot_id;

    IF (current_best IS NULL OR NEW.size_value > current_best)
       AND previous_king IS NOT NULL
       AND previous_king <> NEW.user_id
    THEN
        crown_taken := TRUE;
        bonus_xp := bonus_xp + 200;
        NEW.dethroned_user_id := previous_king;
    END IF;

    -- Coin bonuses requiring history lookups
    IF NOT EXISTS (
        SELECT 1 FROM catches
        WHERE user_id = NEW.user_id
          AND created_at >= date_trunc('day', NOW())
          AND visibility IN ('public', 'friends_only')
    ) THEN
        is_first_catch_today := TRUE;
    END IF;

    IF spot_territory IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM catches c
        JOIN spots s ON s.id = c.spot_id
        WHERE c.user_id = NEW.user_id
          AND s.territory_id = spot_territory
          AND c.visibility IN ('public', 'friends_only')
    ) THEN
        is_first_in_territory := TRUE;
    END IF;

    -- 7-day streak: user has held king of any spot continuously >= 7 days
    SELECT EXISTS (
        SELECT 1 FROM spots
        WHERE current_king_user_id = NEW.user_id
          AND king_since IS NOT NULL
          AND king_since <= NOW() - interval '7 days'
    ) INTO has_7day_streak;

    -- Compute totals
    total_xp := FLOOR((base_xp * species_multiplier) + bonus_xp);
    total_coins := (total_xp / 100) * 10;
    IF crown_taken THEN total_coins := total_coins + 100; END IF;
    IF is_first_catch_today THEN total_coins := total_coins + 25; END IF;
    IF is_first_in_territory THEN total_coins := total_coins + 50; END IF;
    IF has_7day_streak THEN total_coins := total_coins + 200; END IF;

    NEW.xp_awarded := total_xp;
    NEW.coins_awarded := total_coins;

    -- Tag with active season
    SELECT id INTO active_season_id FROM seasons WHERE is_active = true
        ORDER BY start_date DESC LIMIT 1;
    NEW.season_id := active_season_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- AFTER INSERT trigger: write everything that needs the catch row to exist.
-- Spot updates, user codex upserts, notifications, profile XP/coins.
-- ============================================
CREATE OR REPLACE FUNCTION catch_after_insert_apply()
RETURNS TRIGGER AS $$
DECLARE
    current_best DOUBLE PRECISION;
    previous_king UUID;
    crown_taken BOOLEAN := FALSE;
BEGIN
    IF NEW.visibility NOT IN ('public', 'friends_only') THEN
        RETURN NEW;
    END IF;

    SELECT current_best_size, current_king_user_id INTO current_best, previous_king
    FROM spots WHERE id = NEW.spot_id;

    IF (current_best IS NULL OR NEW.size_value > current_best) THEN
        IF previous_king IS NOT NULL AND previous_king <> NEW.user_id THEN
            crown_taken := TRUE;
        END IF;

        UPDATE spots SET
            current_king_user_id = NEW.user_id,
            current_best_catch_id = NEW.id,
            current_best_size = NEW.size_value,
            current_best_unit = NEW.size_unit,
            king_since = NOW(),
            last_catch_at = NOW(),
            total_catches = total_catches + 1,
            updated_at = NOW()
        WHERE id = NEW.spot_id;
    ELSE
        UPDATE spots SET
            last_catch_at = NOW(),
            total_catches = total_catches + 1,
            updated_at = NOW()
        WHERE id = NEW.spot_id;

        -- DEFENDED: someone else challenged and lost. King gets +75 XP + notification.
        IF previous_king IS NOT NULL AND previous_king <> NEW.user_id THEN
            UPDATE profiles SET
                xp = xp + 75,
                season_score = season_score + 75,
                rank_tier = compute_rank_tier(xp + 75),
                updated_at = NOW()
            WHERE id = previous_king;

            INSERT INTO notifications (user_id, type, title, body, payload)
            VALUES (
                previous_king,
                'defended',
                'Spot defended!',
                'A challenger tried to take your crown and failed. +75 XP.',
                jsonb_build_object(
                    'spot_id', NEW.spot_id,
                    'challenger_id', NEW.user_id,
                    'challenger_size', NEW.size_value,
                    'challenger_unit', NEW.size_unit
                )
            );
        END IF;
    END IF;

    -- Update angler profile
    UPDATE profiles SET
        xp = xp + NEW.xp_awarded,
        lure_coins = lure_coins + NEW.coins_awarded,
        season_score = season_score + NEW.xp_awarded,
        rank_tier = compute_rank_tier(xp + NEW.xp_awarded),
        updated_at = NOW()
    WHERE id = NEW.user_id;

    -- Upsert species codex entry
    IF NEW.species_id IS NOT NULL THEN
        INSERT INTO user_species (user_id, species_id, personal_best_size, personal_best_unit, personal_best_catch_id, total_caught, first_caught_at, first_caught_spot_id, last_caught_at)
        VALUES (NEW.user_id, NEW.species_id, NEW.size_value, NEW.size_unit, NEW.id, 1, NOW(), NEW.spot_id, NOW())
        ON CONFLICT (user_id, species_id) DO UPDATE SET
            personal_best_size = GREATEST(user_species.personal_best_size, EXCLUDED.personal_best_size),
            personal_best_unit = CASE
                WHEN EXCLUDED.personal_best_size > user_species.personal_best_size THEN EXCLUDED.personal_best_unit
                ELSE user_species.personal_best_unit
            END,
            personal_best_catch_id = CASE
                WHEN EXCLUDED.personal_best_size > user_species.personal_best_size THEN EXCLUDED.personal_best_catch_id
                ELSE user_species.personal_best_catch_id
            END,
            total_caught = user_species.total_caught + 1,
            last_caught_at = NOW();
    END IF;

    -- Dethrone notification
    IF crown_taken THEN
        INSERT INTO notifications (user_id, type, title, body, payload)
        VALUES (
            previous_king,
            'dethroned',
            'You''ve been dethroned!',
            'Your crown was taken. Take it back.',
            jsonb_build_object(
                'spot_id', NEW.spot_id,
                'new_king_id', NEW.user_id,
                'new_catch_id', NEW.id,
                'new_size', NEW.size_value,
                'new_unit', NEW.size_unit,
                'new_species', NEW.species
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop old single trigger and the old function name from base schema
DROP TRIGGER IF EXISTS on_catch_created ON catches;
DROP FUNCTION IF EXISTS update_spot_king() CASCADE;

-- BEFORE: compute reward fields. AFTER: apply FK-dependent updates.
CREATE TRIGGER on_catch_before
    BEFORE INSERT ON catches
    FOR EACH ROW EXECUTE FUNCTION catch_before_insert_compute();

CREATE TRIGGER on_catch_after
    AFTER INSERT ON catches
    FOR EACH ROW EXECUTE FUNCTION catch_after_insert_apply();

-- ============================================
-- FUNCTION: spot_unique_anglers (recalc helper)
-- ============================================
CREATE OR REPLACE FUNCTION recalc_spot_unique_anglers(p_spot_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE spots SET unique_anglers = (
        SELECT COUNT(DISTINCT user_id)
        FROM catches
        WHERE spot_id = p_spot_id AND visibility IN ('public', 'friends_only')
    )
    WHERE id = p_spot_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: assign_daily_challenges
-- Picks 3 random daily challenges for a user for today.
-- Idempotent per (user_id, today).
-- ============================================
CREATE OR REPLACE FUNCTION assign_daily_challenges(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    today DATE := CURRENT_DATE;
    inserted_count INTEGER := 0;
BEGIN
    -- Skip if already assigned today
    IF EXISTS (
        SELECT 1 FROM user_challenges
        WHERE user_id = p_user_id AND assigned_date = today
        AND challenge_id IN (SELECT id FROM challenges WHERE type = 'daily')
    ) THEN
        RETURN 0;
    END IF;

    INSERT INTO user_challenges (user_id, challenge_id, assigned_date)
    SELECT p_user_id, c.id, today
    FROM challenges c
    WHERE c.type = 'daily' AND c.is_active = true
    ORDER BY random()
    LIMIT 3;

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: assign_weekly_challenge
-- Picks 1 random weekly challenge for a user for this Mon-Sun week.
-- ============================================
CREATE OR REPLACE FUNCTION assign_weekly_challenge(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    week_start DATE := date_trunc('week', CURRENT_DATE)::DATE;
    inserted_count INTEGER := 0;
BEGIN
    IF EXISTS (
        SELECT 1 FROM user_challenges
        WHERE user_id = p_user_id AND assigned_date = week_start
        AND challenge_id IN (SELECT id FROM challenges WHERE type = 'weekly')
    ) THEN
        RETURN 0;
    END IF;

    INSERT INTO user_challenges (user_id, challenge_id, assigned_date)
    SELECT p_user_id, c.id, week_start
    FROM challenges c
    WHERE c.type = 'weekly' AND c.is_active = true
    ORDER BY random()
    LIMIT 1;

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: start_new_season
-- Closes any active season, creates next season, archives champions.
-- ============================================
CREATE OR REPLACE FUNCTION start_new_season(p_length_days INTEGER DEFAULT 30)
RETURNS UUID AS $$
DECLARE
    next_number INTEGER;
    new_id UUID;
    closing_season RECORD;
BEGIN
    -- Close active season + archive top 10 per territory
    FOR closing_season IN SELECT * FROM seasons WHERE is_active = true LOOP
        UPDATE seasons SET is_active = false, end_date = NOW() WHERE id = closing_season.id;

        INSERT INTO season_champions (season_id, user_id, territory_id, rank, season_score)
        SELECT
            closing_season.id,
            ranked.user_id,
            ranked.territory_id,
            ranked.rank,
            ranked.season_score
        FROM (
            SELECT
                p.id AS user_id,
                t.id AS territory_id,
                p.season_score,
                ROW_NUMBER() OVER (PARTITION BY t.id ORDER BY p.season_score DESC) AS rank
            FROM profiles p
            CROSS JOIN territories t
            WHERE p.season_score > 0
        ) ranked
        WHERE ranked.rank <= 10
        ON CONFLICT (season_id, territory_id, rank) DO NOTHING;
    END LOOP;

    -- Reset all season scores
    UPDATE profiles SET season_score = 0 WHERE season_score > 0;

    -- Reset spot kings (per spec: at season start all kings reset)
    UPDATE spots SET
        current_king_user_id = NULL,
        current_best_catch_id = NULL,
        current_best_size = NULL,
        current_best_unit = NULL,
        king_since = NULL,
        updated_at = NOW();

    -- Create next season
    SELECT COALESCE(MAX(season_number), 0) + 1 INTO next_number FROM seasons;

    INSERT INTO seasons (season_number, start_date, end_date, is_active)
    VALUES (next_number, NOW(), NOW() + (p_length_days || ' days')::interval, true)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: purchase_shop_item
-- Atomic coin debit + inventory insert.
-- ============================================
CREATE OR REPLACE FUNCTION purchase_shop_item(p_user_id UUID, p_item_id UUID)
RETURNS JSONB AS $$
DECLARE
    item shop_items%ROWTYPE;
    user_coins INTEGER;
    user_rank TEXT;
    rank_order JSONB := '{"Minnow":0,"Angler":1,"Veteran":2,"Elite":3,"Master":4,"Legend":5}';
BEGIN
    SELECT * INTO item FROM shop_items WHERE id = p_item_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'error', 'item_not_found');
    END IF;

    SELECT lure_coins, rank_tier INTO user_coins, user_rank FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'error', 'user_not_found');
    END IF;

    IF user_coins < item.cost_coins THEN
        RETURN jsonb_build_object('ok', false, 'error', 'insufficient_coins');
    END IF;

    IF item.rank_required IS NOT NULL THEN
        IF (rank_order->>user_rank)::INT < (rank_order->>item.rank_required)::INT THEN
            RETURN jsonb_build_object('ok', false, 'error', 'rank_too_low');
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM user_inventory WHERE user_id = p_user_id AND item_id = p_item_id) THEN
        RETURN jsonb_build_object('ok', false, 'error', 'already_owned');
    END IF;

    UPDATE profiles SET lure_coins = lure_coins - item.cost_coins WHERE id = p_user_id;
    INSERT INTO user_inventory (user_id, item_id) VALUES (p_user_id, p_item_id);

    RETURN jsonb_build_object('ok', true, 'item_id', p_item_id, 'cost', item.cost_coins);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SEED: Season 1 (always-running). Idempotent.
-- ============================================
INSERT INTO seasons (season_number, start_date, end_date, is_active)
SELECT 1, NOW(), NOW() + interval '30 days', true
WHERE NOT EXISTS (SELECT 1 FROM seasons);

-- ============================================
-- FUNCTION: equip_inventory_item
-- Equips one item per category, unequips others in same category.
-- ============================================
CREATE OR REPLACE FUNCTION equip_inventory_item(p_user_id UUID, p_item_id UUID)
RETURNS JSONB AS $$
DECLARE
    item shop_items%ROWTYPE;
BEGIN
    SELECT s.* INTO item
    FROM shop_items s
    JOIN user_inventory ui ON ui.item_id = s.id
    WHERE s.id = p_item_id AND ui.user_id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'error', 'not_owned');
    END IF;

    -- Unequip all items in same category
    UPDATE user_inventory SET is_equipped = false
    WHERE user_id = p_user_id
    AND item_id IN (SELECT id FROM shop_items WHERE category = item.category);

    -- Equip the chosen one
    UPDATE user_inventory SET is_equipped = true
    WHERE user_id = p_user_id AND item_id = p_item_id;

    -- Mirror on profile
    IF item.category = 'rod_skin' THEN
        UPDATE profiles SET equipped_rod_skin_id = p_item_id WHERE id = p_user_id;
    ELSIF item.category = 'badge' THEN
        UPDATE profiles SET equipped_badge_id = p_item_id WHERE id = p_user_id;
    ELSIF item.category = 'flag' THEN
        UPDATE profiles SET equipped_flag_id = p_item_id WHERE id = p_user_id;
    ELSIF item.category = 'frame' THEN
        UPDATE profiles SET equipped_frame_id = p_item_id WHERE id = p_user_id;
    END IF;

    RETURN jsonb_build_object('ok', true, 'item_id', p_item_id, 'category', item.category);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
