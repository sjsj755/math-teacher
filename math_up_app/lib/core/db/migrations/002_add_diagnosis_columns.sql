-- 002_add_diagnosis_columns.sql：阶段三诊断相关列

ALTER TABLE question ADD COLUMN is_timed INTEGER NOT NULL DEFAULT 0;
ALTER TABLE answer_record ADD COLUMN self_option INTEGER;
ALTER TABLE diagnosis ADD COLUMN attribution TEXT;
