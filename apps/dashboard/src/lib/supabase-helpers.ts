import { supabase } from "@/integrations/supabase/client";
import { uploadFile, getFileUrl } from "@/lib/storageService";

// Clients
export const fetchClients = async (options?: { page?: number; pageSize?: number }) => {
  if (options?.page != null && options?.pageSize != null) {
    const from = (options.page! - 1) * options.pageSize!;
    const to = from + options.pageSize! - 1;
    const { data, error, count } = await supabase
      .from("clients")
      .select("*", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(from, to);
    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  }
  const { data, error } = await supabase.from("clients").select("*").order("created_at", { ascending: false });
  if (error) throw error;
  return data;
};

export const createClient = async (client: { name: string; phone?: string; email?: string; address?: string }) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("clients").insert({ ...client, created_by: user.id }).select().single();
  if (error) throw error;
  return data;
};

export const updateClient = async (id: string, updates: Partial<{ name: string; phone: string; email: string; address: string }>) => {
  const { data, error } = await supabase.from("clients").update(updates).eq("id", id).select().single();
  if (error) throw error;
  return data;
};

export const deleteClient = async (id: string) => {
  const { error } = await supabase.from("clients").delete().eq("id", id);
  if (error) throw error;
};

// Cases
export const fetchCases = async (options?: { page?: number; pageSize?: number }) => {
  if (options?.page != null && options?.pageSize != null) {
    const from = (options.page! - 1) * options.pageSize!;
    const to = from + options.pageSize! - 1;
    const { data, error, count } = await supabase
      .from("cases")
      .select("*, clients(name)", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(from, to);
    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  }
  const { data, error } = await supabase.from("cases").select("*, clients(name)").order("created_at", { ascending: false });
  if (error) throw error;
  return data;
};

export const fetchCaseById = async (id: string) => {
  const { data, error } = await supabase.from("cases").select("*, clients(name, phone, email)").eq("id", id).single();
  if (error) throw error;
  return data;
};

export const createCase = async (caseData: {
  client_id: string; case_title: string; case_number?: string; case_type?: string;
  court_name?: string; filing_date?: string; next_hearing_date?: string;
  stage?: string; status?: string;
}) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("cases").insert({ ...caseData, created_by: user.id } as any).select().single();
  if (error) throw error;
  return data;
};

export const updateCase = async (id: string, updates: Record<string, any>) => {
  const { data, error } = await supabase.from("cases").update(updates).eq("id", id).select().single();
  if (error) throw error;
  return data;
};

// Hearings
export const fetchHearings = async (caseId?: string, options?: { page?: number; pageSize?: number }) => {
  let query = supabase.from("hearings").select("*, cases(case_title, case_number)", options?.page != null ? { count: "exact" } : undefined).order("hearing_date", { ascending: true });
  if (caseId) query = query.eq("case_id", caseId);
  if (options?.page != null && options?.pageSize != null) {
    const from = (options.page! - 1) * options.pageSize!;
    const to = from + options.pageSize! - 1;
    const { data, error, count } = await query.range(from, to);
    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  }
  const { data, error } = await query;
  if (error) throw error;
  return data;
};

export const createHearing = async (hearing: { case_id: string; hearing_date: string; stage?: string; notes?: string; next_action?: string }) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("hearings").insert({ ...hearing, created_by: user.id }).select().single();
  if (error) throw error;
  return data;
};

export const adjournHearing = async (id: string, data: {
  current_notes: string;
  next_date: string;
  next_stage: string;
  case_id: string;
}) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  // 1. Update current hearing with notes/outcome
  const { error: updateError } = await supabase
    .from("hearings")
    .update({ notes: data.current_notes })
    .eq("id", id);

  if (updateError) throw updateError;

  // 2. Create new hearing for the next date
  const { data: newHearing, error: insertError } = await supabase
    .from("hearings")
    .insert({
      case_id: data.case_id,
      hearing_date: data.next_date,
      stage: data.next_stage,
      created_by: user.id
    })
    .select()
    .single();

  if (insertError) throw insertError;

  // 3. Update the case's next_hearing_date and stage for convenience
  await supabase
    .from("cases")
    .update({
      next_hearing_date: data.next_date,
      stage: data.next_stage as any
    })
    .eq("id", data.case_id);

  return newHearing;
};

export const deleteHearing = async (id: string) => {
  const { error } = await supabase.from("hearings").delete().eq("id", id);
  if (error) throw error;
};

export const updateHearingStatus = async (id: string, stage: string) => {
  const { data, error } = await supabase.from("hearings").update({ stage }).eq("id", id).select().single();
  if (error) throw error;
  return data;
};

// E-Filing
export const fetchEfilingRecords = async (caseId?: string) => {
  let query = supabase.from("efiling_records").select("*, cases(case_title, case_number)").order("updated_at", { ascending: false });
  if (caseId) query = query.eq("case_id", caseId);
  const { data, error } = await query;
  if (error) throw error;
  return data;
};

export const createEfilingRecord = async (record: { case_id: string; document_type: string; status?: string; filing_date?: string }) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("efiling_records").insert({ ...record, created_by: user.id } as any).select().single();
  if (error) throw error;
  return data;
};

export const updateEfilingRecord = async (id: string, updates: Record<string, any>) => {
  const { data, error } = await supabase.from("efiling_records").update({ ...updates, updated_at: new Date().toISOString() }).eq("id", id).select().single();
  if (error) throw error;
  return data;
};

// Payments
export const fetchPayments = async (caseId?: string, options?: { page?: number; pageSize?: number }) => {
  let query = supabase.from("payments").select("*, cases(case_title, case_number)", options?.page != null ? { count: "exact" } : undefined).order("paid_date", { ascending: false });
  if (caseId) query = query.eq("case_id", caseId);
  if (options?.page != null && options?.pageSize != null) {
    const from = (options.page! - 1) * options.pageSize!;
    const to = from + options.pageSize! - 1;
    const { data, error, count } = await query.range(from, to);
    if (error) throw error;
    return { data: data ?? [], count: count ?? 0 };
  }
  const { data, error } = await query;
  if (error) throw error;
  return data;
};

export const createPayment = async (payment: { 
  case_id: string; 
  total_fee: number; 
  paid_amount: number; 
  balance_amount: number; 
  payment_mode?: string; 
  paid_date?: string;
  transaction_type?: 'revenue' | 'expense';
  notes?: string;
}) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("payments").insert({ 
    ...payment, 
    created_by: user.id,
    transaction_type: payment.transaction_type || 'revenue'
  } as any).select().single();
  if (error) throw error;
  return data;
};

/**
 * Calculates current balance for a case based on ledger logic:
 * Balance = (Base Fee + Total Expenses) - Total Paid
 */
export const fetchCasePaymentSummary = async (caseId: string) => {
  const { data, error } = await supabase
    .from("payments")
    .select("total_fee, paid_amount, transaction_type")
    .eq("case_id", caseId);

  if (error) throw error;
  if (!data || data.length === 0) return { total_fee: 0, total_paid: 0, total_expenses: 0, balance: 0 };

  const baseFee = Number(data[0].total_fee || 0);
  let totalPaid = 0;
  let totalExpenses = 0;

  data.forEach((p: any) => {
    const amount = Number(p.paid_amount || 0);
    if (p.transaction_type === 'expense') {
      totalExpenses += amount;
    } else {
      totalPaid += amount;
    }
  });

  return {
    total_fee: baseFee,
    total_paid: totalPaid,
    total_expenses: totalExpenses,
    balance: (baseFee + totalExpenses) - totalPaid
  };
};

export const deletePayment = async (id: string) => {
  const { error } = await supabase.from("payments").delete().eq("id", id);
  if (error) throw error;
};

// Documents
export const fetchDocuments = async (caseId: string) => {
  const { data, error } = await supabase.from("documents").select("*").eq("case_id", caseId).order("uploaded_at", { ascending: false });
  if (error) throw error;
  return data;
};

export const uploadDocument = async (caseId: string, file: File, documentType: string) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const subPath = `${user.id}/${caseId}`;
  const result = await uploadFile(file, "legal-documents", subPath);
  const fileRef = result.provider === "r2" ? `r2://${result.key}` : result.key;

  const { data, error } = await supabase.from("documents").insert({
    case_id: caseId, document_type: documentType as any, file_url: fileRef, uploaded_by: user.id,
  }).select().single();
  if (error) throw error;
  return data;
};

export const getSignedUrl = async (filePath: string) => {
  if (filePath.startsWith("r2://")) {
    return await getFileUrl(filePath, "r2");
  }
  return await getFileUrl(filePath, "supabase", "legal-documents");
};

// Dashboard stats
export const fetchDashboardStats = async () => {
  const [activeCasesRes, closedCasesRes, hearingsRes, efilingRes, paymentsRes] = await Promise.all([
    supabase.from("cases").select("id, status, stage, court_name").eq("status", "active"),
    supabase.from("cases").select("id, status, stage, court_name").in("status", ["closed", "disposed", "dismissed"]),
    supabase.from("hearings").select("id, hearing_date, case_id, cases(case_title, case_number)").order("hearing_date", { ascending: true }),
    supabase.from("efiling_records").select("id, status, case_id, cases(case_title)"),
    supabase.from("payments").select("id, balance_amount, case_id, cases(case_title)"),
  ]);
  return {
    activeCases: activeCasesRes.data || [],
    closedCases: closedCasesRes.data || [],
    upcomingHearings: hearingsRes.data || [],
    efilingRecords: efilingRes.data || [],
    payments: paymentsRes.data || [],
  };
};

// Global Search
export const searchAll = async (query: string) => {
  const [cases, clients, documents] = await Promise.all([
    supabase.from("cases").select("id, case_title, case_number").or(`case_title.ilike.%${query}%,case_number.ilike.%${query}%`).limit(5),
    supabase.from("clients").select("id, name").ilike("name", `%${query}%`).limit(5),
    supabase.from("documents").select("id, document_type, case_id").ilike("document_type", `%${query}%`).limit(5)
  ]);
  return {
    cases: cases.data || [],
    clients: clients.data || [],
    documents: documents.data || []
  };
};

// Tasks
export const fetchTasks = async () => {
  const { data, error } = await supabase.from("tasks" as any).select("*").order("created_at", { ascending: false });
  if (error) throw error;
  return data;
};

export const createTask = async (title: string) => {
  const { data: { user } } = await supabase.auth.getUser();
  const { data, error } = await supabase.from("tasks" as any).insert({ title, created_by: user.id }).select().single();
  if (error) throw error;
  return data;
};

export const updateTask = async (id: string, updates: Partial<{ title: string; is_completed: boolean }>) => {
  const { data, error } = await supabase.from("tasks" as any).update(updates).eq("id", id).select().single();
  if (error) throw error;
  return data;
};

export const deleteTask = async (id: string) => {
  const { error } = await supabase.from("tasks" as any).delete().eq("id", id);
  if (error) throw error;
};

// Certified Copies
export const fetchCertifiedCopies = async () => {
  const { data, error } = await supabase
    .from("certified_copies")
    .select("*, cases(case_title, case_number)")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
};

export const createCertifiedCopy = async (copy: {
  case_id: string;
  ca_number?: string;
  box_drop_date: string;
  status: string
}) => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase
    .from("certified_copies")
    .insert({ ...copy, created_by: user.id })
    .select()
    .single();
  if (error) throw error;
  return data;
};

export const updateCertifiedCopy = async (id: string, updates: any) => {
  const { data, error } = await supabase
    .from("certified_copies")
    .update(updates)
    .eq("id", id)
    .select()
    .single();
  if (error) throw error;
  return data;
};

export const updateCCStatus = async (id: string, status: string) => {
  return updateCertifiedCopy(id, { status });
};

export const deleteCertifiedCopy = async (id: string) => {
  const { error } = await supabase.from("certified_copies").delete().eq("id", id);
  if (error) throw error;
};

// Advocate Directory
export const fetchAdvocates = async () => {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name, email, mobile_number, practice_state, practice_district, office_address, registration_number")
    .eq("is_public_directory_enabled", true)
    .not("full_name", "is", null)
    .order("full_name");
  if (error) throw error;
  return data;
};

export const createAdvocate = async (advocate: any) => {
  const { data, error } = await supabase
    .from("profiles")
    .upsert({
      ...advocate,
      is_public_directory_enabled: true,
      subscription_tier: "free",
      updated_at: new Date().toISOString()
    }, { 
      onConflict: 'email',
      ignoreDuplicates: false 
    })
    .select()
    .single();
  if (error) throw error;
  return data;
};

export const deleteAdvocate = async (id: string) => {
  console.log("Attempting to delete advocate with ID:", id);
  const { error } = await supabase.from("profiles").delete().eq("id", id);
  if (error) {
    console.error("Delete Advocate Error:", error);
    throw error;
  }
};
