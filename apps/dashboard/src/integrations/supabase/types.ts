export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      cases: {
        Row: {
          case_number: string | null
          case_title: string
          case_type: string | null
          client_id: string
          court_name: string | null
          created_at: string
          created_by: string
          filing_date: string | null
          id: string
          next_hearing_date: string | null
          stage: Database["public"]["Enums"]["case_stage"]
          status: Database["public"]["Enums"]["case_status"]
        }
        Insert: {
          case_number?: string | null
          case_title: string
          case_type?: string | null
          client_id: string
          court_name?: string | null
          created_at?: string
          created_by: string
          filing_date?: string | null
          id?: string
          next_hearing_date?: string | null
          stage?: Database["public"]["Enums"]["case_stage"]
          status?: Database["public"]["Enums"]["case_status"]
        }
        Update: {
          case_number?: string | null
          case_title?: string
          case_type?: string | null
          client_id?: string
          court_name?: string | null
          created_at?: string
          created_by?: string
          filing_date?: string | null
          id?: string
          next_hearing_date?: string | null
          stage?: Database["public"]["Enums"]["case_stage"]
          status?: Database["public"]["Enums"]["case_status"]
        }
        Relationships: [
          {
            foreignKeyName: "cases_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      clients: {
        Row: {
          address: string | null
          created_at: string
          created_by: string
          email: string | null
          id: string
          id_proof_url: string | null
          name: string
          phone: string | null
        }
        Insert: {
          address?: string | null
          created_at?: string
          created_by: string
          email?: string | null
          id?: string
          id_proof_url?: string | null
          name: string
          phone?: string | null
        }
        Update: {
          address?: string | null
          created_at?: string
          created_by?: string
          email?: string | null
          id?: string
          id_proof_url?: string | null
          name?: string
          phone?: string | null
        }
        Relationships: []
      }
      documents: {
        Row: {
          case_id: string
          document_type: Database["public"]["Enums"]["doc_type"]
          file_url: string
          id: string
          uploaded_at: string
          uploaded_by: string
          version: number
        }
        Insert: {
          case_id: string
          document_type?: Database["public"]["Enums"]["doc_type"]
          file_url: string
          id?: string
          uploaded_at?: string
          uploaded_by: string
          version?: number
        }
        Update: {
          case_id?: string
          document_type?: Database["public"]["Enums"]["doc_type"]
          file_url?: string
          id?: string
          uploaded_at?: string
          uploaded_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "documents_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      efiling_records: {
        Row: {
          case_id: string
          created_by: string
          defect_notes: string | null
          document_type: Database["public"]["Enums"]["doc_type"]
          filing_date: string | null
          id: string
          status: Database["public"]["Enums"]["filing_status"]
          updated_at: string
        }
        Insert: {
          case_id: string
          created_by: string
          defect_notes?: string | null
          document_type?: Database["public"]["Enums"]["doc_type"]
          filing_date?: string | null
          id?: string
          status?: Database["public"]["Enums"]["filing_status"]
          updated_at?: string
        }
        Update: {
          case_id?: string
          created_by?: string
          defect_notes?: string | null
          document_type?: Database["public"]["Enums"]["doc_type"]
          filing_date?: string | null
          id?: string
          status?: Database["public"]["Enums"]["filing_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "efiling_records_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      hearings: {
        Row: {
          case_id: string
          created_at: string
          created_by: string
          hearing_date: string
          id: string
          next_action: string | null
          notes: string | null
          stage: string | null
        }
        Insert: {
          case_id: string
          created_at?: string
          created_by: string
          hearing_date: string
          id?: string
          next_action?: string | null
          notes?: string | null
          stage?: string | null
        }
        Update: {
          case_id?: string
          created_at?: string
          created_by?: string
          hearing_date?: string
          id?: string
          next_action?: string | null
          notes?: string | null
          stage?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "hearings_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          balance_amount: number
          case_id: string
          created_by: string
          id: string
          paid_amount: number
          paid_date: string | null
          payment_mode: Database["public"]["Enums"]["payment_mode"] | null
          total_fee: number
        }
        Insert: {
          balance_amount?: number
          case_id: string
          created_by: string
          id?: string
          paid_amount?: number
          paid_date?: string | null
          payment_mode?: Database["public"]["Enums"]["payment_mode"] | null
          total_fee?: number
        }
        Update: {
          balance_amount?: number
          case_id?: string
          created_by?: string
          id?: string
          paid_amount?: number
          paid_date?: string | null
          payment_mode?: Database["public"]["Enums"]["payment_mode"] | null
          total_fee?: number
        }
        Relationships: [
          {
            foreignKeyName: "payments_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          created_at?: string
          full_name?: string
          id: string
          role?: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          created_at?: string
          full_name?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "admin" | "advocate" | "junior" | "clerk"
      case_stage: "filing" | "evidence" | "argument" | "judgment"
      case_status: "active" | "closed" | "appeal"
      doc_type: "plaint" | "affidavit" | "vakalat" | "order" | "judgment"
      filing_status:
      | "drafting"
      | "review"
      | "signature_pending"
      | "filed"
      | "defect"
      | "accepted"
      payment_mode: "cash" | "upi" | "bank_transfer" | "cheque" | "online"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
  | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
  ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
    DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
  : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
    DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
  ? R
  : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
    DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] &
    DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
  ? R
  : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
  | keyof DefaultSchema["Tables"]
  | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
  ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
  : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
    Insert: infer I
  }
  ? I
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
    Insert: infer I
  }
  ? I
  : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
  | keyof DefaultSchema["Tables"]
  | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
  ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
  : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
    Update: infer U
  }
  ? U
  : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
    Update: infer U
  }
  ? U
  : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
  | keyof DefaultSchema["Enums"]
  | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
  ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
  : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
  | keyof DefaultSchema["CompositeTypes"]
  | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
  ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
  : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "advocate", "junior", "clerk"],
      case_stage: ["filing", "evidence", "argument", "judgment"],
      case_status: ["active", "closed", "appeal"],
      doc_type: ["plaint", "affidavit", "vakalat", "order", "judgment"],
      filing_status: [
        "drafting",
        "review",
        "signature_pending",
        "filed",
        "defect",
        "accepted",
      ],
      payment_mode: ["cash", "upi", "bank_transfer", "cheque", "online"],
    },
  },
} as const
