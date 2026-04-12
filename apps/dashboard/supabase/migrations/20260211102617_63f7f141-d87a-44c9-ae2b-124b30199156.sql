
-- Create enums
CREATE TYPE public.app_role AS ENUM ('admin', 'advocate', 'junior', 'clerk');
CREATE TYPE public.case_stage AS ENUM ('filing', 'evidence', 'argument', 'judgment');
CREATE TYPE public.case_status AS ENUM ('active', 'closed', 'appeal');
CREATE TYPE public.doc_type AS ENUM ('plaint', 'affidavit', 'vakalat', 'order', 'judgment');
CREATE TYPE public.filing_status AS ENUM ('drafting', 'review', 'signature_pending', 'filed', 'defect', 'accepted');
CREATE TYPE public.payment_mode AS ENUM ('cash', 'upi', 'bank_transfer', 'cheque', 'online');

-- 1. Profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  role app_role NOT NULL DEFAULT 'advocate',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name) VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
  RETURN NEW;
END;
$$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Clients
CREATE TABLE public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  id_proof_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own clients" ON public.clients FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create clients" ON public.clients FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own clients" ON public.clients FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own clients" ON public.clients FOR DELETE USING (auth.uid() = created_by);

-- 3. Cases
CREATE TABLE public.cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  case_title TEXT NOT NULL,
  case_number TEXT,
  case_type TEXT,
  court_name TEXT,
  filing_date DATE,
  next_hearing_date DATE,
  stage case_stage NOT NULL DEFAULT 'filing',
  status case_status NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own cases" ON public.cases FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create cases" ON public.cases FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own cases" ON public.cases FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own cases" ON public.cases FOR DELETE USING (auth.uid() = created_by);

-- 4. Documents
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  document_type doc_type NOT NULL DEFAULT 'plaint',
  file_url TEXT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own documents" ON public.documents FOR SELECT USING (auth.uid() = uploaded_by);
CREATE POLICY "Users can upload documents" ON public.documents FOR INSERT WITH CHECK (auth.uid() = uploaded_by);
CREATE POLICY "Users can update own documents" ON public.documents FOR UPDATE USING (auth.uid() = uploaded_by);
CREATE POLICY "Users can delete own documents" ON public.documents FOR DELETE USING (auth.uid() = uploaded_by);

-- 5. Hearings
CREATE TABLE public.hearings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  hearing_date DATE NOT NULL,
  stage TEXT,
  notes TEXT,
  next_action TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.hearings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own hearings" ON public.hearings FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create hearings" ON public.hearings FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own hearings" ON public.hearings FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own hearings" ON public.hearings FOR DELETE USING (auth.uid() = created_by);

-- 6. E-Filing Records
CREATE TABLE public.efiling_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  document_type doc_type NOT NULL DEFAULT 'plaint',
  status filing_status NOT NULL DEFAULT 'drafting',
  filing_date DATE,
  defect_notes TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.efiling_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own efiling" ON public.efiling_records FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create efiling" ON public.efiling_records FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own efiling" ON public.efiling_records FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own efiling" ON public.efiling_records FOR DELETE USING (auth.uid() = created_by);

-- 7. Payments
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  total_fee NUMERIC NOT NULL DEFAULT 0,
  paid_amount NUMERIC NOT NULL DEFAULT 0,
  balance_amount NUMERIC NOT NULL DEFAULT 0,
  payment_mode payment_mode,
  paid_date DATE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own payments" ON public.payments FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create payments" ON public.payments FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own payments" ON public.payments FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Users can delete own payments" ON public.payments FOR DELETE USING (auth.uid() = created_by);

-- Storage bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('legal-documents', 'legal-documents', false);
CREATE POLICY "Users can upload legal docs" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'legal-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can view own legal docs" ON storage.objects FOR SELECT USING (bucket_id = 'legal-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete own legal docs" ON storage.objects FOR DELETE USING (bucket_id = 'legal-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.efiling_records;
ALTER PUBLICATION supabase_realtime ADD TABLE public.hearings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cases;

-- User roles
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  UNIQUE(user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
