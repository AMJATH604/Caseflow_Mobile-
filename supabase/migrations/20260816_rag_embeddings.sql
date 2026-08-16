-- ═══════════════════════════════════════════════════════════
-- CaseFlow RAG: Legal Knowledge Embeddings
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════

-- 1) Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2) Legal knowledge embeddings table
CREATE TABLE IF NOT EXISTS legal_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,            -- The actual legal text chunk
  source_type TEXT NOT NULL,        -- 'bare_act', 'template', 'dictionary'
  source_ref TEXT NOT NULL,         -- 'BNS 2023 - Section 101' or 'Template: Bail Application'
  act_id UUID,                      -- Reference to bare_acts table (nullable for non-act sources)
  section_id TEXT,                  -- Section identifier
  metadata JSONB DEFAULT '{}',     -- { act_title, section_number, chapter, category, ... }
  embedding VECTOR(3072),          -- gemini-embedding-001 outputs 3072 dimensions
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3) Similarity search index (IVFFlat for fast approximate nearest neighbor)
CREATE INDEX IF NOT EXISTS legal_embeddings_vector_idx
  ON legal_embeddings
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 4) Index for filtering by source type
CREATE INDEX IF NOT EXISTS legal_embeddings_source_type_idx
  ON legal_embeddings (source_type);

-- 5) RLS: public read (needed for RAG search without auth), service_role write
ALTER TABLE legal_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on legal_embeddings"
  ON legal_embeddings FOR SELECT
  USING (true);

CREATE POLICY "Allow service_role insert on legal_embeddings"
  ON legal_embeddings FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow service_role update on legal_embeddings"
  ON legal_embeddings FOR UPDATE
  USING (true);

CREATE POLICY "Allow service_role delete on legal_embeddings"
  ON legal_embeddings FOR DELETE
  USING (true);

-- 6) Helper function for similarity search (called by rag-search Edge Function)
CREATE OR REPLACE FUNCTION match_legal_documents(
  query_embedding VECTOR(3072),
  match_threshold FLOAT DEFAULT 0.3,
  match_count INT DEFAULT 5,
  filter_source_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  source_type TEXT,
  source_ref TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    le.id,
    le.content,
    le.source_type,
    le.source_ref,
    le.metadata,
    1 - (le.embedding <=> query_embedding) AS similarity
  FROM legal_embeddings le
  WHERE 
    (filter_source_type IS NULL OR le.source_type = filter_source_type)
    AND 1 - (le.embedding <=> query_embedding) > match_threshold
  ORDER BY le.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
