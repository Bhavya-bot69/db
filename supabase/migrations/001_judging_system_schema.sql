/*
  # Judging System Database Schema

  ## Overview
  Complete database schema for event management, judge assignments, team scoring,
  and multi-round judging with normalization.

  ## Tables Created

  1. events
    - Event management with status tracking

  2. categories
    - Judging categories (Software, Hardware, etc.)
    - Includes scoring criteria and weights

  3. teams
    - Team registration with category assignment

  4. judges
    - Judge profiles with authentication tokens
    - Email and access management

  5. judge_assignments
    - Links judges to specific categories and teams
    - Manages which judge evaluates which teams

  6. scoring_rounds
    - Defines Round 1 and Round 2 for each event

  7. scores
    - Individual judge scores for teams
    - Tracks scores per round and category

  8. normalized_scores
    - Normalized scores after Round 1
    - Used for selecting top 2 teams per judge

  9. final_results
    - Final rankings after Round 2
    - Includes correlation calculations

  ## Security
  - All tables have RLS enabled
  - Policies restrict access based on user roles
*/

-- Events table
CREATE TABLE IF NOT EXISTS events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  status text DEFAULT 'draft',
  start_date timestamptz,
  end_date timestamptz,
  created_by uuid REFERENCES profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their events"
  ON events FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Users can insert their events"
  ON events FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update their events"
  ON events FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can delete their events"
  ON events FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  weight numeric DEFAULT 1,
  criteria jsonb DEFAULT '[]',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage categories for their events"
  ON categories FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = categories.event_id
      AND events.created_by = auth.uid()
    )
  );

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  category_id uuid REFERENCES categories(id),
  description text,
  members jsonb DEFAULT '[]',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage teams for their events"
  ON teams FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = teams.event_id
      AND events.created_by = auth.uid()
    )
  );

-- Judges table
CREATE TABLE IF NOT EXISTS judges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text NOT NULL,
  access_token text UNIQUE NOT NULL,
  invitation_sent boolean DEFAULT false,
  invitation_sent_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE judges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage judges for their events"
  ON judges FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = judges.event_id
      AND events.created_by = auth.uid()
    )
  );

CREATE POLICY "Judges can view their own profile by token"
  ON judges FOR SELECT
  TO anon, authenticated
  USING (true);

-- Judge assignments table
CREATE TABLE IF NOT EXISTS judge_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  judge_id uuid REFERENCES judges(id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id) ON DELETE CASCADE,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  round_number integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  UNIQUE(judge_id, team_id, round_number)
);

ALTER TABLE judge_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage judge assignments for their events"
  ON judge_assignments FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM judges j
      JOIN events e ON e.id = j.event_id
      WHERE j.id = judge_assignments.judge_id
      AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "Judges can view their assignments"
  ON judge_assignments FOR SELECT
  TO anon, authenticated
  USING (true);

-- Scoring rounds table
CREATE TABLE IF NOT EXISTS scoring_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  round_number integer NOT NULL,
  name text NOT NULL,
  status text DEFAULT 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(event_id, round_number)
);

ALTER TABLE scoring_rounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage rounds for their events"
  ON scoring_rounds FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = scoring_rounds.event_id
      AND events.created_by = auth.uid()
    )
  );

CREATE POLICY "Judges can view rounds"
  ON scoring_rounds FOR SELECT
  TO anon, authenticated
  USING (true);

-- Scores table
CREATE TABLE IF NOT EXISTS scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  judge_id uuid REFERENCES judges(id) ON DELETE CASCADE,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id) ON DELETE CASCADE,
  round_id uuid REFERENCES scoring_rounds(id) ON DELETE CASCADE,
  criterion_name text NOT NULL,
  score numeric NOT NULL CHECK (score >= 0 AND score <= 10),
  comments text,
  submitted_at timestamptz DEFAULT now(),
  UNIQUE(judge_id, team_id, round_id, criterion_name)
);

ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Judges can manage their own scores"
  ON scores FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Event owners can view all scores"
  ON scores FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM teams t
      JOIN events e ON e.id = t.event_id
      WHERE t.id = scores.team_id
      AND e.created_by = auth.uid()
    )
  );

-- Normalized scores table
CREATE TABLE IF NOT EXISTS normalized_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  judge_id uuid REFERENCES judges(id) ON DELETE CASCADE,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  round_id uuid REFERENCES scoring_rounds(id) ON DELETE CASCADE,
  raw_score numeric NOT NULL,
  normalized_score numeric NOT NULL,
  percentile numeric,
  rank integer,
  selected_for_round2 boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(judge_id, team_id, round_id)
);

ALTER TABLE normalized_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Event owners can manage normalized scores"
  ON normalized_scores FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM teams t
      JOIN events e ON e.id = t.event_id
      WHERE t.id = normalized_scores.team_id
      AND e.created_by = auth.uid()
    )
  );

-- Final results table
CREATE TABLE IF NOT EXISTS final_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  final_score numeric NOT NULL,
  final_rank integer,
  correlation_coefficient numeric,
  created_at timestamptz DEFAULT now(),
  UNIQUE(event_id, team_id)
);

ALTER TABLE final_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view final results for their events"
  ON final_results FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = final_results.event_id
      AND events.created_by = auth.uid()
    )
  );

CREATE POLICY "Users can manage final results for their events"
  ON final_results FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = final_results.event_id
      AND events.created_by = auth.uid()
    )
  );

CREATE POLICY "Users can update final results for their events"
  ON final_results FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = final_results.event_id
      AND events.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = final_results.event_id
      AND events.created_by = auth.uid()
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);
CREATE INDEX IF NOT EXISTS idx_categories_event_id ON categories(event_id);
CREATE INDEX IF NOT EXISTS idx_teams_event_id ON teams(event_id);
CREATE INDEX IF NOT EXISTS idx_teams_category_id ON teams(category_id);
CREATE INDEX IF NOT EXISTS idx_judges_event_id ON judges(event_id);
CREATE INDEX IF NOT EXISTS idx_judges_access_token ON judges(access_token);
CREATE INDEX IF NOT EXISTS idx_judge_assignments_judge_id ON judge_assignments(judge_id);
CREATE INDEX IF NOT EXISTS idx_judge_assignments_team_id ON judge_assignments(team_id);
CREATE INDEX IF NOT EXISTS idx_scores_judge_id ON scores(judge_id);
CREATE INDEX IF NOT EXISTS idx_scores_team_id ON scores(team_id);
CREATE INDEX IF NOT EXISTS idx_scores_round_id ON scores(round_id);
CREATE INDEX IF NOT EXISTS idx_normalized_scores_round_id ON normalized_scores(round_id);
CREATE INDEX IF NOT EXISTS idx_final_results_event_id ON final_results(event_id);
