import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://huaqldjkgyosefzfhjnf.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
);

// First create the table via raw SQL using the REST API
const createTableSQL = `
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'tierheim', 'tierschutz', 'suppenküche', 'obdachlosenhilfe', 
    'tafel', 'kleiderkammer', 'sozialkaufhaus', 'krisentelefon',
    'notschlafstelle', 'jugend', 'senioren', 'behinderung',
    'sucht', 'flüchtlingshilfe', 'allgemein'
  )),
  description TEXT,
  address TEXT,
  city TEXT NOT NULL,
  country TEXT NOT NULL CHECK (country IN ('DE', 'AT', 'CH')),
  zip_code TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  opening_hours TEXT,
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- Allow everyone to read
CREATE POLICY IF NOT EXISTS "Organizations are publicly readable" 
  ON public.organizations FOR SELECT USING (true);
`;

// Use the management API to run SQL
const response = await fetch(
  'https://huaqldjkgyosefzfhjnf.supabase.co/rest/v1/rpc/exec_sql',
  {
    method: 'POST',
    headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ query: createTableSQL })
  }
);

const result = await response.text();
console.log('Create table response:', response.status, result.substring(0, 200));
