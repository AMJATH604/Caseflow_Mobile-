-- ═══════════════════════════════════════════════════════════════════
-- Migration: Case Strategy Board
-- Feature: Collaborative Kanban-style task management per case
-- ═══════════════════════════════════════════════════════════════════

-- ─── Table 1: strategy_tasks (Core task cards) ──────────────────
CREATE TABLE IF NOT EXISTS strategy_tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id         UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT,
    stage           TEXT NOT NULL DEFAULT 'todo'
                    CHECK (stage IN ('todo', 'in_progress', 'review', 'filed', 'done')),
    position        INTEGER NOT NULL DEFAULT 0,
    assigned_to     UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_by      UUID NOT NULL REFERENCES profiles(id),
    priority        TEXT NOT NULL DEFAULT 'medium'
                    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    due_date        DATE,
    linked_hearing_id UUID REFERENCES hearings(id) ON DELETE SET NULL,
    firm_id         TEXT,
    is_auto_generated BOOLEAN DEFAULT false,
    completed_at    TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_strategy_tasks_case
    ON strategy_tasks(case_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_strategy_tasks_assigned
    ON strategy_tasks(assigned_to) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_strategy_tasks_stage
    ON strategy_tasks(case_id, stage) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_strategy_tasks_due
    ON strategy_tasks(due_date) WHERE deleted_at IS NULL AND stage != 'done';
CREATE INDEX IF NOT EXISTS idx_strategy_tasks_firm
    ON strategy_tasks(firm_id) WHERE deleted_at IS NULL;

-- ─── Table 2: task_comments ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS task_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES strategy_tasks(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES profiles(id),
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_comments_task
    ON task_comments(task_id);

-- ─── Table 3: task_attachments ──────────────────────────────────
CREATE TABLE IF NOT EXISTS task_attachments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id         UUID NOT NULL REFERENCES strategy_tasks(id) ON DELETE CASCADE,
    uploaded_by     UUID NOT NULL REFERENCES profiles(id),
    file_url        TEXT NOT NULL,
    file_name       TEXT NOT NULL,
    file_size       BIGINT,
    mime_type       TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_attachments_task
    ON task_attachments(task_id);

-- ─── Table 4: task_activity_log ─────────────────────────────────
CREATE TABLE IF NOT EXISTS task_activity_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES strategy_tasks(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES profiles(id),
    action      TEXT NOT NULL,
    old_value   TEXT,
    new_value   TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_activity_task
    ON task_activity_log(task_id);

-- ─── Trigger: Auto-set completed_at & updated_at ────────────────
CREATE OR REPLACE FUNCTION handle_strategy_task_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Set completed_at when moved to 'done'
    IF NEW.stage = 'done' AND (OLD.stage IS NULL OR OLD.stage != 'done') THEN
        NEW.completed_at = now();
    ELSIF NEW.stage != 'done' THEN
        NEW.completed_at = NULL;
    END IF;
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_strategy_task_update
    BEFORE UPDATE ON strategy_tasks
    FOR EACH ROW
    EXECUTE FUNCTION handle_strategy_task_update();

-- ─── RLS Policies ───────────────────────────────────────────────
ALTER TABLE strategy_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_activity_log ENABLE ROW LEVEL SECURITY;

-- Strategy Tasks: SELECT
CREATE POLICY "strategy_tasks_select" ON strategy_tasks
    FOR SELECT USING (
        created_by = auth.uid()
        OR assigned_to = auth.uid()
        OR firm_id = auth.uid()::text
        OR firm_id = (SELECT firm_id FROM profiles WHERE id = auth.uid())
    );

-- Strategy Tasks: INSERT
CREATE POLICY "strategy_tasks_insert" ON strategy_tasks
    FOR INSERT WITH CHECK (created_by = auth.uid());

-- Strategy Tasks: UPDATE
CREATE POLICY "strategy_tasks_update" ON strategy_tasks
    FOR UPDATE USING (
        created_by = auth.uid()
        OR assigned_to = auth.uid()
        OR firm_id = auth.uid()::text
    );

-- Strategy Tasks: DELETE
CREATE POLICY "strategy_tasks_delete" ON strategy_tasks
    FOR DELETE USING (
        created_by = auth.uid()
        OR firm_id = auth.uid()::text
    );

-- Task Comments: SELECT (visible if task is visible)
CREATE POLICY "task_comments_select" ON task_comments
    FOR SELECT USING (
        task_id IN (SELECT id FROM strategy_tasks)
    );

-- Task Comments: INSERT
CREATE POLICY "task_comments_insert" ON task_comments
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Task Attachments: SELECT
CREATE POLICY "task_attachments_select" ON task_attachments
    FOR SELECT USING (
        task_id IN (SELECT id FROM strategy_tasks)
    );

-- Task Attachments: INSERT
CREATE POLICY "task_attachments_insert" ON task_attachments
    FOR INSERT WITH CHECK (uploaded_by = auth.uid());

-- Task Attachments: DELETE
CREATE POLICY "task_attachments_delete" ON task_attachments
    FOR DELETE USING (uploaded_by = auth.uid());

-- Task Activity Log: SELECT
CREATE POLICY "task_activity_select" ON task_activity_log
    FOR SELECT USING (
        task_id IN (SELECT id FROM strategy_tasks)
    );

-- Task Activity Log: INSERT
CREATE POLICY "task_activity_insert" ON task_activity_log
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ─── Enable Realtime ────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE strategy_tasks;
