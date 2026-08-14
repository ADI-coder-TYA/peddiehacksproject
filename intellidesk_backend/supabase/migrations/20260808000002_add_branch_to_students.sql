-- Add branch, department, and student_id columns to students table
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS branch TEXT;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS department TEXT;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS student_id TEXT;
