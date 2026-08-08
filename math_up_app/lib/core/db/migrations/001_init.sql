-- 001_init.sql：阶段二初始表结构（对应开发文档表 5）

CREATE TABLE IF NOT EXISTS question (
  id TEXT PRIMARY KEY,
  chapter TEXT NOT NULL,
  knowledge_point TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('choice', 'fill', 'essay', 'self_s', 'self_p')),
  difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
  thinking_method TEXT,
  lose_type TEXT NOT NULL CHECK (lose_type IN ('knowledge', 'method', 'calculation', 'standard', 'psychology')),
  stem TEXT NOT NULL,
  options TEXT,
  answer TEXT NOT NULL,
  explain TEXT,
  variant_group TEXT NOT NULL,
  tags TEXT
);

CREATE INDEX IF NOT EXISTS idx_question_chapter ON question(chapter);
CREATE INDEX IF NOT EXISTS idx_question_knowledge ON question(knowledge_point);
CREATE INDEX IF NOT EXISTS idx_question_variant ON question(variant_group);

CREATE TABLE IF NOT EXISTS diagnosis (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  k_score REAL NOT NULL DEFAULT 0,
  t_score REAL NOT NULL DEFAULT 0,
  s_score REAL NOT NULL DEFAULT 0,
  p_score REAL NOT NULL DEFAULT 0,
  weak_points TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS answer_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id TEXT NOT NULL REFERENCES question(id),
  result INTEGER NOT NULL CHECK (result IN (0, 1)),
  seconds INTEGER NOT NULL DEFAULT 0,
  date TEXT NOT NULL,
  diagnosis_id INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_answer_record_question ON answer_record(question_id);
CREATE INDEX IF NOT EXISTS idx_answer_record_date ON answer_record(date);

CREATE TABLE IF NOT EXISTS error_book (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id TEXT NOT NULL UNIQUE REFERENCES question(id),
  lose_type TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'redone', 'mastered', 'pending_upgrade')),
  redo_count INTEGER NOT NULL DEFAULT 0,
  first_wrong_at TEXT,
  last_redo_at TEXT,
  review_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_error_book_status ON error_book(status);

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS digest_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  payload TEXT NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX IF NOT EXISTS idx_digest_queue_synced ON digest_queue(synced);
