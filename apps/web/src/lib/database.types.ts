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
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      ai_chat_history: {
        Row: {
          attachment_type: string | null
          created_at: string | null
          has_attachment: boolean | null
          id: string
          message: string
          role: string
          session_id: string | null
          user_id: string
        }
        Insert: {
          attachment_type?: string | null
          created_at?: string | null
          has_attachment?: boolean | null
          id?: string
          message: string
          role: string
          session_id?: string | null
          user_id: string
        }
        Update: {
          attachment_type?: string | null
          created_at?: string | null
          has_attachment?: boolean | null
          id?: string
          message?: string
          role?: string
          session_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_chat_history_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "ai_chat_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_chat_sessions: {
        Row: {
          created_at: string
          id: string
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          title?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          title?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      app_config: {
        Row: {
          key: string
          updated_at: string | null
          value: string
        }
        Insert: {
          key: string
          updated_at?: string | null
          value: string
        }
        Update: {
          key?: string
          updated_at?: string | null
          value?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          actor_email: string | null
          actor_name: string | null
          context: string | null
          created_at: string
          details: Json | null
          entity: string
          entity_id: string
          id: string
          user_id: string | null
        }
        Insert: {
          action: string
          actor_email?: string | null
          actor_name?: string | null
          context?: string | null
          created_at?: string
          details?: Json | null
          entity: string
          entity_id: string
          id?: string
          user_id?: string | null
        }
        Update: {
          action?: string
          actor_email?: string | null
          actor_name?: string | null
          context?: string | null
          created_at?: string
          details?: Json | null
          entity?: string
          entity_id?: string
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      bar_admins: {
        Row: {
          association_id: string
          created_at: string | null
          id: string
          role: string | null
          user_id: string
        }
        Insert: {
          association_id: string
          created_at?: string | null
          id?: string
          role?: string | null
          user_id: string
        }
        Update: {
          association_id?: string
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_admins_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_associations: {
        Row: {
          address: string | null
          annual_fee: number | null
          contact_email: string | null
          contact_phone: string | null
          court: string
          created_at: string | null
          district: string
          id: string
          invite_code: string
          junior_stipend_floor: number
          logo_url: string | null
          name: string
          president_name: string | null
          secretary_name: string | null
          subscription_expires_at: string | null
          subscription_plan: string | null
          treasurer_name: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          annual_fee?: number | null
          contact_email?: string | null
          contact_phone?: string | null
          court: string
          created_at?: string | null
          district: string
          id?: string
          invite_code: string
          junior_stipend_floor?: number
          logo_url?: string | null
          name: string
          president_name?: string | null
          secretary_name?: string | null
          subscription_expires_at?: string | null
          subscription_plan?: string | null
          treasurer_name?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          annual_fee?: number | null
          contact_email?: string | null
          contact_phone?: string | null
          court?: string
          created_at?: string | null
          district?: string
          id?: string
          invite_code?: string
          junior_stipend_floor?: number
          logo_url?: string | null
          name?: string
          president_name?: string | null
          secretary_name?: string | null
          subscription_expires_at?: string | null
          subscription_plan?: string | null
          treasurer_name?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      bar_condolences: {
        Row: {
          age: number | null
          association_id: string
          created_at: string
          date_of_death: string
          deceased_name: string
          enrolment_number: string | null
          fcm_sent: boolean
          id: string
          meeting_at: string | null
          meeting_venue: string | null
          member_id: string | null
          message: string | null
          no_work_resolution: boolean
          published_at: string
          published_by: string | null
        }
        Insert: {
          age?: number | null
          association_id: string
          created_at?: string
          date_of_death: string
          deceased_name: string
          enrolment_number?: string | null
          fcm_sent?: boolean
          id?: string
          meeting_at?: string | null
          meeting_venue?: string | null
          member_id?: string | null
          message?: string | null
          no_work_resolution?: boolean
          published_at?: string
          published_by?: string | null
        }
        Update: {
          age?: number | null
          association_id?: string
          created_at?: string
          date_of_death?: string
          deceased_name?: string
          enrolment_number?: string | null
          fcm_sent?: boolean
          id?: string
          meeting_at?: string | null
          meeting_venue?: string | null
          member_id?: string | null
          message?: string | null
          no_work_resolution?: boolean
          published_at?: string
          published_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bar_condolences_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_condolences_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_events: {
        Row: {
          agenda: string | null
          association_id: string
          category: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          end_time: string | null
          event_date: string
          id: string
          location: string | null
          start_time: string | null
          title: string
        }
        Insert: {
          agenda?: string | null
          association_id: string
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          end_time?: string | null
          event_date: string
          id?: string
          location?: string | null
          start_time?: string | null
          title: string
        }
        Update: {
          agenda?: string | null
          association_id?: string
          category?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          end_time?: string | null
          event_date?: string
          id?: string
          location?: string | null
          start_time?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_events_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_fee_payments: {
        Row: {
          amount: number
          association_id: string
          created_at: string | null
          fee_year: number
          id: string
          member_id: string
          paid_at: string | null
          payment_method: string | null
          razorpay_order_id: string | null
          razorpay_payment_id: string | null
          receipt_number: string | null
          status: string | null
        }
        Insert: {
          amount: number
          association_id: string
          created_at?: string | null
          fee_year: number
          id?: string
          member_id: string
          paid_at?: string | null
          payment_method?: string | null
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          receipt_number?: string | null
          status?: string | null
        }
        Update: {
          amount?: number
          association_id?: string
          created_at?: string | null
          fee_year?: number
          id?: string
          member_id?: string
          paid_at?: string | null
          payment_method?: string | null
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          receipt_number?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bar_fee_payments_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_fee_payments_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_join_attempts: {
        Row: {
          attempted_at: string
          id: number
          user_id: string
        }
        Insert: {
          attempted_at?: string
          id?: never
          user_id: string
        }
        Update: {
          attempted_at?: string
          id?: never
          user_id?: string
        }
        Relationships: []
      }
      bar_members: {
        Row: {
          address: string | null
          association_id: string
          blood_group: string | null
          created_at: string | null
          date_of_birth: string | null
          date_of_death: string | null
          email: string | null
          enrollment_number: string | null
          enrolment_date: string | null
          fee_paid_until: number | null
          id: string
          id_card_issued_on: string | null
          id_card_number: string | null
          id_card_valid_until: string | null
          is_caseflow_user: boolean | null
          is_deceased: boolean
          joined_year: number | null
          member_class: string
          membership_expires_on: string | null
          membership_type: string | null
          mobile: string
          name: string
          notes: string | null
          photo_url: string | null
          status: string | null
          updated_at: string
          user_id: string | null
          welfare_fund_number: string | null
          welfare_fund_status: string
          works_under_member_id: string | null
        }
        Insert: {
          address?: string | null
          association_id: string
          blood_group?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          date_of_death?: string | null
          email?: string | null
          enrollment_number?: string | null
          enrolment_date?: string | null
          fee_paid_until?: number | null
          id?: string
          id_card_issued_on?: string | null
          id_card_number?: string | null
          id_card_valid_until?: string | null
          is_caseflow_user?: boolean | null
          is_deceased?: boolean
          joined_year?: number | null
          member_class?: string
          membership_expires_on?: string | null
          membership_type?: string | null
          mobile: string
          name: string
          notes?: string | null
          photo_url?: string | null
          status?: string | null
          updated_at?: string
          user_id?: string | null
          welfare_fund_number?: string | null
          welfare_fund_status?: string
          works_under_member_id?: string | null
        }
        Update: {
          address?: string | null
          association_id?: string
          blood_group?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          date_of_death?: string | null
          email?: string | null
          enrollment_number?: string | null
          enrolment_date?: string | null
          fee_paid_until?: number | null
          id?: string
          id_card_issued_on?: string | null
          id_card_number?: string | null
          id_card_valid_until?: string | null
          is_caseflow_user?: boolean | null
          is_deceased?: boolean
          joined_year?: number | null
          member_class?: string
          membership_expires_on?: string | null
          membership_type?: string | null
          mobile?: string
          name?: string
          notes?: string | null
          photo_url?: string | null
          status?: string | null
          updated_at?: string
          user_id?: string | null
          welfare_fund_number?: string | null
          welfare_fund_status?: string
          works_under_member_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bar_members_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_members_works_under_member_id_fkey"
            columns: ["works_under_member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_notice_reads: {
        Row: {
          id: string
          member_id: string
          notice_id: string
          read_at: string | null
        }
        Insert: {
          id?: string
          member_id: string
          notice_id: string
          read_at?: string | null
        }
        Update: {
          id?: string
          member_id?: string
          notice_id?: string
          read_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bar_notice_reads_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_notice_reads_notice_id_fkey"
            columns: ["notice_id"]
            isOneToOne: false
            referencedRelation: "bar_notices"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_notices: {
        Row: {
          association_id: string
          body: string
          category: string | null
          created_at: string | null
          fcm_sent: boolean | null
          id: string
          is_pinned: boolean | null
          published_at: string | null
          published_by: string | null
          read_count: number | null
          scheduled_for: string | null
          title: string
        }
        Insert: {
          association_id: string
          body: string
          category?: string | null
          created_at?: string | null
          fcm_sent?: boolean | null
          id?: string
          is_pinned?: boolean | null
          published_at?: string | null
          published_by?: string | null
          read_count?: number | null
          scheduled_for?: string | null
          title: string
        }
        Update: {
          association_id?: string
          body?: string
          category?: string | null
          created_at?: string | null
          fcm_sent?: boolean | null
          id?: string
          is_pinned?: boolean | null
          published_at?: string | null
          published_by?: string | null
          read_count?: number | null
          scheduled_for?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_notices_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_stipend_declarations: {
        Row: {
          association_id: string
          confirmed_at: string | null
          confirmed_by_junior: boolean
          created_at: string
          declared_by: string | null
          effective_from: string
          effective_to: string | null
          id: string
          junior_member_id: string | null
          junior_mobile: string | null
          junior_name: string
          monthly_stipend: number
          senior_member_id: string
          updated_at: string
        }
        Insert: {
          association_id: string
          confirmed_at?: string | null
          confirmed_by_junior?: boolean
          created_at?: string
          declared_by?: string | null
          effective_from: string
          effective_to?: string | null
          id?: string
          junior_member_id?: string | null
          junior_mobile?: string | null
          junior_name: string
          monthly_stipend: number
          senior_member_id: string
          updated_at?: string
        }
        Update: {
          association_id?: string
          confirmed_at?: string | null
          confirmed_by_junior?: boolean
          created_at?: string
          declared_by?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          junior_member_id?: string | null
          junior_mobile?: string | null
          junior_name?: string
          monthly_stipend?: number
          senior_member_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_stipend_declarations_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_stipend_declarations_junior_member_id_fkey"
            columns: ["junior_member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_stipend_declarations_senior_member_id_fkey"
            columns: ["senior_member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_welfare_claims: {
        Row: {
          amount: number | null
          association_id: string
          claim_type: string
          claimant_mobile: string | null
          claimant_name: string | null
          claimant_relation: string | null
          created_at: string
          created_by: string | null
          defect_notes: string | null
          id: string
          member_id: string | null
          reference_number: string | null
          sanctioned_on: string | null
          status: string
          submitted_on: string | null
          updated_at: string
        }
        Insert: {
          amount?: number | null
          association_id: string
          claim_type: string
          claimant_mobile?: string | null
          claimant_name?: string | null
          claimant_relation?: string | null
          created_at?: string
          created_by?: string | null
          defect_notes?: string | null
          id?: string
          member_id?: string | null
          reference_number?: string | null
          sanctioned_on?: string | null
          status?: string
          submitted_on?: string | null
          updated_at?: string
        }
        Update: {
          amount?: number | null
          association_id?: string
          claim_type?: string
          claimant_mobile?: string | null
          claimant_name?: string | null
          claimant_relation?: string | null
          created_at?: string
          created_by?: string | null
          defect_notes?: string | null
          id?: string
          member_id?: string | null
          reference_number?: string | null
          sanctioned_on?: string | null
          status?: string
          submitted_on?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_welfare_claims_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_welfare_claims_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bar_welfare_stamps: {
        Row: {
          association_id: string
          denomination: number
          id: string
          member_id: string | null
          notes: string | null
          quantity: number
          recorded_at: string
          recorded_by: string | null
          txn_type: string
        }
        Insert: {
          association_id: string
          denomination?: number
          id?: string
          member_id?: string | null
          notes?: string | null
          quantity: number
          recorded_at?: string
          recorded_by?: string | null
          txn_type: string
        }
        Update: {
          association_id?: string
          denomination?: number
          id?: string
          member_id?: string | null
          notes?: string | null
          quantity?: number
          recorded_at?: string
          recorded_by?: string | null
          txn_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "bar_welfare_stamps_association_id_fkey"
            columns: ["association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bar_welfare_stamps_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "bar_members"
            referencedColumns: ["id"]
          },
        ]
      }
      bare_act_sections: {
        Row: {
          act_id: string | null
          chapter_number: string | null
          chapter_title: string | null
          content: string | null
          created_at: string | null
          id: string
          search_vector: unknown
          section_number: string | null
          section_text: string | null
          section_title: string | null
          sequence_order: number | null
          title: string | null
        }
        Insert: {
          act_id?: string | null
          chapter_number?: string | null
          chapter_title?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          search_vector?: unknown
          section_number?: string | null
          section_text?: string | null
          section_title?: string | null
          sequence_order?: number | null
          title?: string | null
        }
        Update: {
          act_id?: string | null
          chapter_number?: string | null
          chapter_title?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          search_vector?: unknown
          section_number?: string | null
          section_text?: string | null
          section_title?: string | null
          sequence_order?: number | null
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bare_act_sections_act_id_fkey"
            columns: ["act_id"]
            isOneToOne: false
            referencedRelation: "bare_acts"
            referencedColumns: ["id"]
          },
        ]
      }
      bare_acts: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          is_active: boolean | null
          pdf_url: string | null
          short_title: string | null
          title: string
          year: number | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          pdf_url?: string | null
          short_title?: string | null
          title: string
          year?: number | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          pdf_url?: string | null
          short_title?: string | null
          title?: string
          year?: number | null
        }
        Relationships: []
      }
      carousel_slides: {
        Row: {
          action: string
          active: boolean
          body: string
          created_at: string
          custom_route_path: string
          detail_body: string
          detail_title: string
          gradient_colors: string[]
          icon_name: string
          id: string
          title: string
          tool_id: string | null
          type: string
        }
        Insert: {
          action: string
          active?: boolean
          body: string
          created_at?: string
          custom_route_path: string
          detail_body: string
          detail_title: string
          gradient_colors: string[]
          icon_name: string
          id?: string
          title: string
          tool_id?: string | null
          type: string
        }
        Update: {
          action?: string
          active?: boolean
          body?: string
          created_at?: string
          custom_route_path?: string
          detail_body?: string
          detail_title?: string
          gradient_colors?: string[]
          icon_name?: string
          id?: string
          title?: string
          tool_id?: string | null
          type?: string
        }
        Relationships: []
      }
      case_acts: {
        Row: {
          act_name: string
          case_id: string
          created_at: string | null
          created_by: string
          id: string
          section_number: string | null
        }
        Insert: {
          act_name: string
          case_id: string
          created_at?: string | null
          created_by: string
          id?: string
          section_number?: string | null
        }
        Update: {
          act_name?: string
          case_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          section_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "case_acts_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      case_collaborations: {
        Row: {
          case_id: string
          collaborator_email: string
          collaborator_id: string | null
          created_at: string
          id: string
          owner_id: string | null
          responded_at: string | null
          status: string
        }
        Insert: {
          case_id: string
          collaborator_email: string
          collaborator_id?: string | null
          created_at?: string
          id?: string
          owner_id?: string | null
          responded_at?: string | null
          status?: string
        }
        Update: {
          case_id?: string
          collaborator_email?: string
          collaborator_id?: string | null
          created_at?: string
          id?: string
          owner_id?: string | null
          responded_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "case_collaborations_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "case_collaborations_collaborator_id_profiles_fkey"
            columns: ["collaborator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "case_collaborations_owner_id_profiles_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      case_discussions: {
        Row: {
          attachment_type: string | null
          attachment_url: string | null
          case_id: string | null
          created_at: string | null
          edited_at: string | null
          firm_id: string | null
          id: string
          is_system: boolean | null
          message: string
          notified_at: string | null
          reply_to_id: string | null
          reply_to_message: string | null
          reply_to_sender: string | null
          sender_id: string | null
          sender_name: string | null
        }
        Insert: {
          attachment_type?: string | null
          attachment_url?: string | null
          case_id?: string | null
          created_at?: string | null
          edited_at?: string | null
          firm_id?: string | null
          id?: string
          is_system?: boolean | null
          message: string
          notified_at?: string | null
          reply_to_id?: string | null
          reply_to_message?: string | null
          reply_to_sender?: string | null
          sender_id?: string | null
          sender_name?: string | null
        }
        Update: {
          attachment_type?: string | null
          attachment_url?: string | null
          case_id?: string | null
          created_at?: string | null
          edited_at?: string | null
          firm_id?: string | null
          id?: string
          is_system?: boolean | null
          message?: string
          notified_at?: string | null
          reply_to_id?: string | null
          reply_to_message?: string | null
          reply_to_sender?: string | null
          sender_id?: string | null
          sender_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "case_discussions_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "case_discussions_firm_id_fkey"
            columns: ["firm_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "case_discussions_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "case_discussions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "case_discussions_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      case_ia_applications: {
        Row: {
          case_id: string
          classification: string | null
          created_at: string | null
          created_by: string
          filing_date: string | null
          ia_number: string
          ia_status: string | null
          id: string
          next_date: string | null
          party: string | null
        }
        Insert: {
          case_id: string
          classification?: string | null
          created_at?: string | null
          created_by: string
          filing_date?: string | null
          ia_number: string
          ia_status?: string | null
          id?: string
          next_date?: string | null
          party?: string | null
        }
        Update: {
          case_id?: string
          classification?: string | null
          created_at?: string | null
          created_by?: string
          filing_date?: string | null
          ia_number?: string
          ia_status?: string | null
          id?: string
          next_date?: string | null
          party?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "case_ia_applications_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      case_interim_orders: {
        Row: {
          case_id: string
          created_at: string | null
          created_by: string
          document_url: string | null
          id: string
          order_date: string
          order_number: number | null
          order_summary: string | null
          order_type: string | null
        }
        Insert: {
          case_id: string
          created_at?: string | null
          created_by: string
          document_url?: string | null
          id?: string
          order_date: string
          order_number?: number | null
          order_summary?: string | null
          order_type?: string | null
        }
        Update: {
          case_id?: string
          created_at?: string | null
          created_by?: string
          document_url?: string | null
          id?: string
          order_date?: string
          order_number?: number | null
          order_summary?: string | null
          order_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "case_interim_orders_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      cases: {
        Row: {
          assigned_to: string | null
          case_number: string | null
          case_title: string
          case_type: string | null
          client_id: string | null
          cnr_number: string | null
          court_name: string | null
          court_type: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          description: string | null
          district: string | null
          filing_date: string | null
          firm_id: string | null
          id: string
          is_auto_sync_enabled: boolean | null
          judge_name: string | null
          last_auto_sync_at: string | null
          next_hearing_date: string | null
          opposing_advocate: string | null
          opposing_advocate_phone: string | null
          opposing_party: string | null
          petitioner_advocate: string | null
          petitioner_advocate_phone: string | null
          representation_type: string | null
          stage: string | null
          state: string | null
          status: string | null
          title: string | null
          updated_at: string | null
        }
        Insert: {
          assigned_to?: string | null
          case_number?: string | null
          case_title: string
          case_type?: string | null
          client_id?: string | null
          cnr_number?: string | null
          court_name?: string | null
          court_type?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          district?: string | null
          filing_date?: string | null
          firm_id?: string | null
          id?: string
          is_auto_sync_enabled?: boolean | null
          judge_name?: string | null
          last_auto_sync_at?: string | null
          next_hearing_date?: string | null
          opposing_advocate?: string | null
          opposing_advocate_phone?: string | null
          opposing_party?: string | null
          petitioner_advocate?: string | null
          petitioner_advocate_phone?: string | null
          representation_type?: string | null
          stage?: string | null
          state?: string | null
          status?: string | null
          title?: string | null
          updated_at?: string | null
        }
        Update: {
          assigned_to?: string | null
          case_number?: string | null
          case_title?: string
          case_type?: string | null
          client_id?: string | null
          cnr_number?: string | null
          court_name?: string | null
          court_type?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          district?: string | null
          filing_date?: string | null
          firm_id?: string | null
          id?: string
          is_auto_sync_enabled?: boolean | null
          judge_name?: string | null
          last_auto_sync_at?: string | null
          next_hearing_date?: string | null
          opposing_advocate?: string | null
          opposing_advocate_phone?: string | null
          opposing_party?: string | null
          petitioner_advocate?: string | null
          petitioner_advocate_phone?: string | null
          representation_type?: string | null
          stage?: string | null
          state?: string | null
          status?: string | null
          title?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cases_assigned_to_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cases_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cases_created_by_profiles_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cases_firm_id_fkey"
            columns: ["firm_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      caveats: {
        Row: {
          case_type: string | null
          caveat_number: string | null
          caveator_name: string
          court_name: string
          created_at: string | null
          expiry_date: string
          filing_date: string
          id: string
          notes: string | null
          opponent_name: string
          status: string
          subject_matter: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          case_type?: string | null
          caveat_number?: string | null
          caveator_name: string
          court_name: string
          created_at?: string | null
          expiry_date: string
          filing_date: string
          id?: string
          notes?: string | null
          opponent_name: string
          status?: string
          subject_matter?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          case_type?: string | null
          caveat_number?: string | null
          caveator_name?: string
          court_name?: string
          created_at?: string | null
          expiry_date?: string
          filing_date?: string
          id?: string
          notes?: string | null
          opponent_name?: string
          status?: string
          subject_matter?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      certified_copies: {
        Row: {
          application_date: string | null
          box_drop_date: string | null
          ca_number: string | null
          case_id: string | null
          collected_date: string | null
          created_at: string | null
          created_by: string | null
          delivered_date: string | null
          document_type: string | null
          id: string
          memo_date: string | null
          notes: string | null
          paid_amount: number | null
          portal_receipt_url: string | null
          ready_date: string | null
          receipt_number: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          application_date?: string | null
          box_drop_date?: string | null
          ca_number?: string | null
          case_id?: string | null
          collected_date?: string | null
          created_at?: string | null
          created_by?: string | null
          delivered_date?: string | null
          document_type?: string | null
          id?: string
          memo_date?: string | null
          notes?: string | null
          paid_amount?: number | null
          portal_receipt_url?: string | null
          ready_date?: string | null
          receipt_number?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          application_date?: string | null
          box_drop_date?: string | null
          ca_number?: string | null
          case_id?: string | null
          collected_date?: string | null
          created_at?: string | null
          created_by?: string | null
          delivered_date?: string | null
          document_type?: string | null
          id?: string
          memo_date?: string | null
          notes?: string | null
          paid_amount?: number | null
          portal_receipt_url?: string | null
          ready_date?: string | null
          receipt_number?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "certified_copies_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      chambers_reads: {
        Row: {
          firm_id: string
          last_read_at: string
          user_id: string
        }
        Insert: {
          firm_id: string
          last_read_at?: string
          user_id: string
        }
        Update: {
          firm_id?: string
          last_read_at?: string
          user_id?: string
        }
        Relationships: []
      }
      clients: {
        Row: {
          address: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          district: string | null
          email: string | null
          firm_id: string | null
          id: string
          name: string
          phone: string | null
          state: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          district?: string | null
          email?: string | null
          firm_id?: string | null
          id?: string
          name: string
          phone?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          district?: string | null
          email?: string | null
          firm_id?: string | null
          id?: string
          name?: string
          phone?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      commission_evidence: {
        Row: {
          caption: string | null
          commission_id: string
          created_at: string | null
          created_by: string
          direction: string | null
          file_type: string
          file_url: string
          id: string
          latitude: number | null
          longitude: number | null
          sequence_number: number | null
          sha256_hash: string | null
          thumbnail_url: string | null
          visit_id: string
        }
        Insert: {
          caption?: string | null
          commission_id: string
          created_at?: string | null
          created_by: string
          direction?: string | null
          file_type?: string
          file_url: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          sequence_number?: number | null
          sha256_hash?: string | null
          thumbnail_url?: string | null
          visit_id: string
        }
        Update: {
          caption?: string | null
          commission_id?: string
          created_at?: string | null
          created_by?: string
          direction?: string | null
          file_type?: string
          file_url?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          sequence_number?: number | null
          sha256_hash?: string | null
          thumbnail_url?: string | null
          visit_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "commission_evidence_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commission_evidence_visit_id_fkey"
            columns: ["visit_id"]
            isOneToOne: false
            referencedRelation: "commission_visits"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_expenses: {
        Row: {
          amount: number
          commission_id: string
          created_at: string | null
          created_by: string
          description: string | null
          expense_date: string | null
          expense_type: string
          id: string
          receipt_url: string | null
        }
        Insert: {
          amount?: number
          commission_id: string
          created_at?: string | null
          created_by: string
          description?: string | null
          expense_date?: string | null
          expense_type?: string
          id?: string
          receipt_url?: string | null
        }
        Update: {
          amount?: number
          commission_id?: string
          created_at?: string | null
          created_by?: string
          description?: string | null
          expense_date?: string | null
          expense_type?: string
          id?: string
          receipt_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commission_expenses_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_notifications: {
        Row: {
          body: string | null
          commission_id: string
          created_at: string | null
          created_by: string
          id: string
          notification_type: string
          scheduled_at: string
          sent: boolean | null
          title: string
        }
        Insert: {
          body?: string | null
          commission_id: string
          created_at?: string | null
          created_by: string
          id?: string
          notification_type?: string
          scheduled_at?: string
          sent?: boolean | null
          title: string
        }
        Update: {
          body?: string | null
          commission_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          notification_type?: string
          scheduled_at?: string
          sent?: boolean | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "commission_notifications_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_observations: {
        Row: {
          commission_id: string
          content: string
          created_at: string | null
          created_by: string
          id: string
          observation_type: string
          sequence_order: number | null
          tags: string[] | null
          visit_id: string
          voice_note_url: string | null
        }
        Insert: {
          commission_id: string
          content: string
          created_at?: string | null
          created_by: string
          id?: string
          observation_type?: string
          sequence_order?: number | null
          tags?: string[] | null
          visit_id: string
          voice_note_url?: string | null
        }
        Update: {
          commission_id?: string
          content?: string
          created_at?: string | null
          created_by?: string
          id?: string
          observation_type?: string
          sequence_order?: number | null
          tags?: string[] | null
          visit_id?: string
          voice_note_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commission_observations_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commission_observations_visit_id_fkey"
            columns: ["visit_id"]
            isOneToOne: false
            referencedRelation: "commission_visits"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_reports: {
        Row: {
          commission_id: string
          created_at: string | null
          created_by: string
          id: string
          pdf_url: string | null
          report_content: string | null
          status: string
          submitted_date: string | null
          updated_at: string | null
          version: number | null
        }
        Insert: {
          commission_id: string
          created_at?: string | null
          created_by: string
          id?: string
          pdf_url?: string | null
          report_content?: string | null
          status?: string
          submitted_date?: string | null
          updated_at?: string | null
          version?: number | null
        }
        Update: {
          commission_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          pdf_url?: string | null
          report_content?: string | null
          status?: string
          submitted_date?: string | null
          updated_at?: string | null
          version?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "commission_reports_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_sketches: {
        Row: {
          annotations: Json | null
          commission_id: string
          created_at: string | null
          created_by: string
          id: string
          north_angle: number | null
          sketch_data: Json | null
          sketch_image_url: string | null
          sketch_type: string
          title: string | null
          updated_at: string | null
          visit_id: string | null
        }
        Insert: {
          annotations?: Json | null
          commission_id: string
          created_at?: string | null
          created_by: string
          id?: string
          north_angle?: number | null
          sketch_data?: Json | null
          sketch_image_url?: string | null
          sketch_type?: string
          title?: string | null
          updated_at?: string | null
          visit_id?: string | null
        }
        Update: {
          annotations?: Json | null
          commission_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          north_angle?: number | null
          sketch_data?: Json | null
          sketch_image_url?: string | null
          sketch_type?: string
          title?: string | null
          updated_at?: string | null
          visit_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commission_sketches_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commission_sketches_visit_id_fkey"
            columns: ["visit_id"]
            isOneToOne: false
            referencedRelation: "commission_visits"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_visits: {
        Row: {
          checkin_address: string | null
          checkin_lat: number | null
          checkin_lng: number | null
          checkin_time: string | null
          checkout_address: string | null
          checkout_lat: number | null
          checkout_lng: number | null
          checkout_time: string | null
          commission_id: string
          created_at: string | null
          created_by: string
          id: string
          obstruction_details: string | null
          persons_present: string | null
          visit_date: string
          visit_status: string
          weather_conditions: string | null
        }
        Insert: {
          checkin_address?: string | null
          checkin_lat?: number | null
          checkin_lng?: number | null
          checkin_time?: string | null
          checkout_address?: string | null
          checkout_lat?: number | null
          checkout_lng?: number | null
          checkout_time?: string | null
          commission_id: string
          created_at?: string | null
          created_by: string
          id?: string
          obstruction_details?: string | null
          persons_present?: string | null
          visit_date?: string
          visit_status?: string
          weather_conditions?: string | null
        }
        Update: {
          checkin_address?: string | null
          checkin_lat?: number | null
          checkin_lng?: number | null
          checkin_time?: string | null
          checkout_address?: string | null
          checkout_lat?: number | null
          checkout_lng?: number | null
          checkout_time?: string | null
          commission_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          obstruction_details?: string | null
          persons_present?: string | null
          visit_date?: string
          visit_status?: string
          weather_conditions?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commission_visits_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
        ]
      }
      commission_witnesses: {
        Row: {
          audio_url: string | null
          commission_id: string
          created_at: string | null
          created_by: string
          id: string
          id_number: string | null
          id_type: string | null
          latitude: number | null
          longitude: number | null
          photo_url: string | null
          signature_url: string | null
          statement_text: string | null
          visit_id: string
          witness_name: string
        }
        Insert: {
          audio_url?: string | null
          commission_id: string
          created_at?: string | null
          created_by: string
          id?: string
          id_number?: string | null
          id_type?: string | null
          latitude?: number | null
          longitude?: number | null
          photo_url?: string | null
          signature_url?: string | null
          statement_text?: string | null
          visit_id: string
          witness_name: string
        }
        Update: {
          audio_url?: string | null
          commission_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          id_number?: string | null
          id_type?: string | null
          latitude?: number | null
          longitude?: number | null
          photo_url?: string | null
          signature_url?: string | null
          statement_text?: string | null
          visit_id?: string
          witness_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "commission_witnesses_commission_id_fkey"
            columns: ["commission_id"]
            isOneToOne: false
            referencedRelation: "commissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commission_witnesses_visit_id_fkey"
            columns: ["visit_id"]
            isOneToOne: false
            referencedRelation: "commission_visits"
            referencedColumns: ["id"]
          },
        ]
      }
      commissions: {
        Row: {
          case_id: string | null
          case_number_ref: string | null
          commission_type: string
          commissioner_id: string | null
          court_name: string | null
          created_at: string | null
          created_by: string
          deadline_date: string | null
          district: string | null
          execution_date: string | null
          firm_id: string | null
          id: string
          notes: string | null
          party_petitioner: string | null
          party_respondent: string | null
          property_description: string | null
          scope_of_work: string | null
          state: string | null
          status: string
          survey_number: string | null
          taluk: string | null
          updated_at: string | null
          village: string | null
          warrant_date: string | null
        }
        Insert: {
          case_id?: string | null
          case_number_ref?: string | null
          commission_type?: string
          commissioner_id?: string | null
          court_name?: string | null
          created_at?: string | null
          created_by: string
          deadline_date?: string | null
          district?: string | null
          execution_date?: string | null
          firm_id?: string | null
          id?: string
          notes?: string | null
          party_petitioner?: string | null
          party_respondent?: string | null
          property_description?: string | null
          scope_of_work?: string | null
          state?: string | null
          status?: string
          survey_number?: string | null
          taluk?: string | null
          updated_at?: string | null
          village?: string | null
          warrant_date?: string | null
        }
        Update: {
          case_id?: string | null
          case_number_ref?: string | null
          commission_type?: string
          commissioner_id?: string | null
          court_name?: string | null
          created_at?: string | null
          created_by?: string
          deadline_date?: string | null
          district?: string | null
          execution_date?: string | null
          firm_id?: string | null
          id?: string
          notes?: string | null
          party_petitioner?: string | null
          party_respondent?: string | null
          property_description?: string | null
          scope_of_work?: string | null
          state?: string | null
          status?: string
          survey_number?: string | null
          taluk?: string | null
          updated_at?: string | null
          village?: string | null
          warrant_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "commissions_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      cross_exam_questions: {
        Row: {
          advocate_notes: string | null
          category: string | null
          created_at: string | null
          expected_answer: string | null
          follow_up_if_no: string | null
          follow_up_if_yes: string | null
          id: string
          is_key_question: boolean | null
          position: number | null
          priority: string | null
          question_text: string
          session_id: string
          updated_at: string | null
        }
        Insert: {
          advocate_notes?: string | null
          category?: string | null
          created_at?: string | null
          expected_answer?: string | null
          follow_up_if_no?: string | null
          follow_up_if_yes?: string | null
          id?: string
          is_key_question?: boolean | null
          position?: number | null
          priority?: string | null
          question_text: string
          session_id: string
          updated_at?: string | null
        }
        Update: {
          advocate_notes?: string | null
          category?: string | null
          created_at?: string | null
          expected_answer?: string | null
          follow_up_if_no?: string | null
          follow_up_if_yes?: string | null
          id?: string
          is_key_question?: boolean | null
          position?: number | null
          priority?: string | null
          question_text?: string
          session_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cross_exam_questions_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "cross_exam_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      cross_exam_sessions: {
        Row: {
          case_id: string
          created_at: string | null
          deleted_at: string | null
          firm_id: string | null
          hearing_date: string | null
          id: string
          notes: string | null
          status: string | null
          updated_at: string | null
          user_id: string
          witness_id: string | null
          witness_name: string
          witness_tag: string | null
        }
        Insert: {
          case_id: string
          created_at?: string | null
          deleted_at?: string | null
          firm_id?: string | null
          hearing_date?: string | null
          id?: string
          notes?: string | null
          status?: string | null
          updated_at?: string | null
          user_id: string
          witness_id?: string | null
          witness_name: string
          witness_tag?: string | null
        }
        Update: {
          case_id?: string
          created_at?: string | null
          deleted_at?: string | null
          firm_id?: string | null
          hearing_date?: string | null
          id?: string
          notes?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string
          witness_id?: string | null
          witness_name?: string
          witness_tag?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cross_exam_sessions_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      device_tokens: {
        Row: {
          created_at: string | null
          device_type: string | null
          fcm_token: string
          id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          device_type?: string | null
          fcm_token: string
          id?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          device_type?: string | null
          fcm_token?: string
          id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      direct_conversations: {
        Row: {
          created_at: string | null
          id: string
          last_message_at: string | null
          participant_1: string
          participant_2: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_message_at?: string | null
          participant_1: string
          participant_2: string
        }
        Update: {
          created_at?: string | null
          id?: string
          last_message_at?: string | null
          participant_1?: string
          participant_2?: string
        }
        Relationships: [
          {
            foreignKeyName: "direct_conversations_participant_1_fkey"
            columns: ["participant_1"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_conversations_participant_2_fkey"
            columns: ["participant_2"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      direct_messages: {
        Row: {
          attachment_type: string | null
          attachment_url: string | null
          conversation_id: string
          created_at: string | null
          delivered_at: string | null
          edited_at: string | null
          id: string
          is_read: boolean | null
          message: string
          notified_at: string | null
          reply_to_id: string | null
          reply_to_message: string | null
          reply_to_sender: string | null
          sender_id: string
        }
        Insert: {
          attachment_type?: string | null
          attachment_url?: string | null
          conversation_id: string
          created_at?: string | null
          delivered_at?: string | null
          edited_at?: string | null
          id?: string
          is_read?: boolean | null
          message: string
          notified_at?: string | null
          reply_to_id?: string | null
          reply_to_message?: string | null
          reply_to_sender?: string | null
          sender_id: string
        }
        Update: {
          attachment_type?: string | null
          attachment_url?: string | null
          conversation_id?: string
          created_at?: string | null
          delivered_at?: string | null
          edited_at?: string | null
          id?: string
          is_read?: boolean | null
          message?: string
          notified_at?: string | null
          reply_to_id?: string | null
          reply_to_message?: string | null
          reply_to_sender?: string | null
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "direct_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "direct_conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "direct_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      district_portals: {
        Row: {
          created_at: string | null
          district: string
          id: string
          portal_type: string
          state: string
          url: string
        }
        Insert: {
          created_at?: string | null
          district: string
          id?: string
          portal_type?: string
          state: string
          url: string
        }
        Update: {
          created_at?: string | null
          district?: string
          id?: string
          portal_type?: string
          state?: string
          url?: string
        }
        Relationships: []
      }
      ecourt_hearing_history: {
        Row: {
          business_done: string | null
          case_id: string | null
          cnr_number: string | null
          court_number: string | null
          created_at: string | null
          created_by: string | null
          hearing_date: string
          id: string
          judge_name: string | null
          next_date: string | null
          order_text: string | null
          purpose: string | null
          source: string | null
        }
        Insert: {
          business_done?: string | null
          case_id?: string | null
          cnr_number?: string | null
          court_number?: string | null
          created_at?: string | null
          created_by?: string | null
          hearing_date: string
          id?: string
          judge_name?: string | null
          next_date?: string | null
          order_text?: string | null
          purpose?: string | null
          source?: string | null
        }
        Update: {
          business_done?: string | null
          case_id?: string | null
          cnr_number?: string | null
          court_number?: string | null
          created_at?: string | null
          created_by?: string | null
          hearing_date?: string
          id?: string
          judge_name?: string | null
          next_date?: string | null
          order_text?: string | null
          purpose?: string | null
          source?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ecourt_hearing_history_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      ecourt_sync_records: {
        Row: {
          case_id: string | null
          case_status: string | null
          cnr_number: string | null
          court_number: string | null
          created_at: string | null
          id: string
          judge_name: string | null
          last_hearing_date: string | null
          last_hearing_purpose: string | null
          next_hearing_date: string | null
          parsed_data: Json | null
          raw_data: string | null
          sync_source: string | null
          synced_at: string | null
          synced_by: string | null
        }
        Insert: {
          case_id?: string | null
          case_status?: string | null
          cnr_number?: string | null
          court_number?: string | null
          created_at?: string | null
          id?: string
          judge_name?: string | null
          last_hearing_date?: string | null
          last_hearing_purpose?: string | null
          next_hearing_date?: string | null
          parsed_data?: Json | null
          raw_data?: string | null
          sync_source?: string | null
          synced_at?: string | null
          synced_by?: string | null
        }
        Update: {
          case_id?: string | null
          case_status?: string | null
          cnr_number?: string | null
          court_number?: string | null
          created_at?: string | null
          id?: string
          judge_name?: string | null
          last_hearing_date?: string | null
          last_hearing_purpose?: string | null
          next_hearing_date?: string | null
          parsed_data?: Json | null
          raw_data?: string | null
          sync_source?: string | null
          synced_at?: string | null
          synced_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ecourt_sync_records_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      efiling_records: {
        Row: {
          ack_number: string | null
          case_id: string | null
          created_at: string | null
          created_by: string | null
          doc_type: string
          id: string
          status: string | null
          updated_at: string | null
        }
        Insert: {
          ack_number?: string | null
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          doc_type: string
          id?: string
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          ack_number?: string | null
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          doc_type?: string
          id?: string
          status?: string | null
          updated_at?: string | null
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
      evidence_checklists: {
        Row: {
          case_id: string | null
          created_at: string | null
          created_by: string | null
          id: string
          item_name: string
          notes: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          item_name: string
          notes?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          item_name?: string
          notes?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "evidence_checklists_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      evidence_photos: {
        Row: {
          caption: string | null
          case_id: string | null
          created_at: string | null
          created_by: string | null
          id: string
          photo_url: string
          updated_at: string | null
        }
        Insert: {
          caption?: string | null
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          photo_url: string
          updated_at?: string | null
        }
        Update: {
          caption?: string | null
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          photo_url?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "evidence_photos_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      fcm_tokens: {
        Row: {
          created_at: string | null
          device_info: string | null
          id: string
          token: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          device_info?: string | null
          id?: string
          token: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          device_info?: string | null
          id?: string
          token?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      firm_members: {
        Row: {
          created_at: string | null
          id: string
          member_email: string
          member_id: string | null
          owner_id: string | null
          responded_at: string | null
          role: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          member_email: string
          member_id?: string | null
          owner_id?: string | null
          responded_at?: string | null
          role?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          member_email?: string
          member_id?: string | null
          owner_id?: string | null
          responded_at?: string | null
          role?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "firm_members_junior_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "firm_members_senior_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      hearings: {
        Row: {
          case_id: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          hearing_date: string
          id: string
          notes: string | null
          purpose: string | null
          stage: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          hearing_date: string
          id?: string
          notes?: string | null
          purpose?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          hearing_date?: string
          id?: string
          notes?: string | null
          purpose?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
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
      hearings_dedupe_backup: {
        Row: {
          backed_up_at: string
          case_id: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          hearing_date: string
          id: string
          notes: string | null
          purpose: string | null
          stage: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          backed_up_at?: string
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          hearing_date: string
          id?: string
          notes?: string | null
          purpose?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          backed_up_at?: string
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          hearing_date?: string
          id?: string
          notes?: string | null
          purpose?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      legal_embeddings: {
        Row: {
          act_id: string | null
          content: string
          created_at: string | null
          embedding: string | null
          id: string
          metadata: Json | null
          section_id: string | null
          source_ref: string
          source_type: string
        }
        Insert: {
          act_id?: string | null
          content: string
          created_at?: string | null
          embedding?: string | null
          id?: string
          metadata?: Json | null
          section_id?: string | null
          source_ref: string
          source_type: string
        }
        Update: {
          act_id?: string | null
          content?: string
          created_at?: string | null
          embedding?: string | null
          id?: string
          metadata?: Json | null
          section_id?: string | null
          source_ref?: string
          source_type?: string
        }
        Relationships: []
      }
      legal_news: {
        Row: {
          category: string
          created_at: string | null
          fetched_at: string | null
          id: string
          image_url: string | null
          link: string
          published_at: string | null
          source: string
          summary: string | null
          title: string
        }
        Insert: {
          category?: string
          created_at?: string | null
          fetched_at?: string | null
          id?: string
          image_url?: string | null
          link: string
          published_at?: string | null
          source?: string
          summary?: string | null
          title: string
        }
        Update: {
          category?: string
          created_at?: string | null
          fetched_at?: string | null
          id?: string
          image_url?: string | null
          link?: string
          published_at?: string | null
          source?: string
          summary?: string | null
          title?: string
        }
        Relationships: []
      }
      legal_news_bookmarks: {
        Row: {
          article_id: string
          created_at: string | null
          id: string
          user_id: string
        }
        Insert: {
          article_id: string
          created_at?: string | null
          id?: string
          user_id: string
        }
        Update: {
          article_id?: string
          created_at?: string | null
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "legal_news_bookmarks_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "legal_news"
            referencedColumns: ["id"]
          },
        ]
      }
      legal_templates: {
        Row: {
          category: string | null
          created_at: string | null
          description: string | null
          docx_url: string | null
          file_url: string | null
          id: string
          pdf_url: string | null
          title: string
        }
        Insert: {
          category?: string | null
          created_at?: string | null
          description?: string | null
          docx_url?: string | null
          file_url?: string | null
          id?: string
          pdf_url?: string | null
          title: string
        }
        Update: {
          category?: string | null
          created_at?: string | null
          description?: string | null
          docx_url?: string | null
          file_url?: string | null
          id?: string
          pdf_url?: string | null
          title?: string
        }
        Relationships: []
      }
      message_reactions: {
        Row: {
          created_at: string
          emoji: string
          id: string
          message_id: string
          scope: string
          user_id: string
        }
        Insert: {
          created_at?: string
          emoji: string
          id?: string
          message_id: string
          scope: string
          user_id: string
        }
        Update: {
          created_at?: string
          emoji?: string
          id?: string
          message_id?: string
          scope?: string
          user_id?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          dedupe_key: string | null
          id: string
          payload: Json
          read_at: string | null
          route: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body?: string
          created_at?: string
          dedupe_key?: string | null
          id?: string
          payload?: Json
          read_at?: string | null
          route?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          dedupe_key?: string | null
          id?: string
          payload?: Json
          read_at?: string | null
          route?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      payments: {
        Row: {
          balance_amount: number | null
          case_id: string | null
          certified_copy_id: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          id: string
          notes: string | null
          paid_amount: number | null
          paid_date: string | null
          payment_mode: string | null
          status: string | null
          total_fee: number | null
          transaction_type: string | null
          updated_at: string | null
        }
        Insert: {
          balance_amount?: number | null
          case_id?: string | null
          certified_copy_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          notes?: string | null
          paid_amount?: number | null
          paid_date?: string | null
          payment_mode?: string | null
          status?: string | null
          total_fee?: number | null
          transaction_type?: string | null
          updated_at?: string | null
        }
        Update: {
          balance_amount?: number | null
          case_id?: string | null
          certified_copy_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          notes?: string | null
          paid_amount?: number | null
          paid_date?: string | null
          payment_mode?: string | null
          status?: string | null
          total_fee?: number | null
          transaction_type?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_certified_copy_id_fkey"
            columns: ["certified_copy_id"]
            isOneToOne: false
            referencedRelation: "certified_copies"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          bar_association_id: string | null
          created_at: string | null
          current_period_end: string | null
          email: string | null
          firm_id: string | null
          full_name: string | null
          id: string
          is_admin: boolean | null
          is_public_directory_enabled: boolean | null
          last_seen_at: string | null
          mobile_number: string | null
          office_address: string | null
          practice_district: string | null
          practice_state: string | null
          registration_number: string | null
          subscription_tier: string | null
          trial_ends_at: string | null
          updated_at: string | null
          user_role: string
        }
        Insert: {
          avatar_url?: string | null
          bar_association_id?: string | null
          created_at?: string | null
          current_period_end?: string | null
          email?: string | null
          firm_id?: string | null
          full_name?: string | null
          id: string
          is_admin?: boolean | null
          is_public_directory_enabled?: boolean | null
          last_seen_at?: string | null
          mobile_number?: string | null
          office_address?: string | null
          practice_district?: string | null
          practice_state?: string | null
          registration_number?: string | null
          subscription_tier?: string | null
          trial_ends_at?: string | null
          updated_at?: string | null
          user_role?: string
        }
        Update: {
          avatar_url?: string | null
          bar_association_id?: string | null
          created_at?: string | null
          current_period_end?: string | null
          email?: string | null
          firm_id?: string | null
          full_name?: string | null
          id?: string
          is_admin?: boolean | null
          is_public_directory_enabled?: boolean | null
          last_seen_at?: string | null
          mobile_number?: string | null
          office_address?: string | null
          practice_district?: string | null
          practice_state?: string | null
          registration_number?: string | null
          subscription_tier?: string | null
          trial_ends_at?: string | null
          updated_at?: string | null
          user_role?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_bar_association_id_fkey"
            columns: ["bar_association_id"]
            isOneToOne: false
            referencedRelation: "bar_associations"
            referencedColumns: ["id"]
          },
        ]
      }
      stamp_values: {
        Row: {
          category: string
          created_at: string | null
          icon_name: string | null
          id: string
          name: string
          state_id: string | null
          updated_at: string | null
          value: string
        }
        Insert: {
          category: string
          created_at?: string | null
          icon_name?: string | null
          id?: string
          name: string
          state_id?: string | null
          updated_at?: string | null
          value: string
        }
        Update: {
          category?: string
          created_at?: string | null
          icon_name?: string | null
          id?: string
          name?: string
          state_id?: string | null
          updated_at?: string | null
          value?: string
        }
        Relationships: []
      }
      strategy_tasks: {
        Row: {
          assigned_to: string | null
          case_id: string
          completed_at: string | null
          created_at: string | null
          created_by: string
          deleted_at: string | null
          description: string | null
          due_date: string | null
          firm_id: string | null
          id: string
          is_auto_generated: boolean | null
          linked_hearing_id: string | null
          position: number
          priority: string
          stage: string
          title: string
          updated_at: string | null
        }
        Insert: {
          assigned_to?: string | null
          case_id: string
          completed_at?: string | null
          created_at?: string | null
          created_by: string
          deleted_at?: string | null
          description?: string | null
          due_date?: string | null
          firm_id?: string | null
          id?: string
          is_auto_generated?: boolean | null
          linked_hearing_id?: string | null
          position?: number
          priority?: string
          stage?: string
          title: string
          updated_at?: string | null
        }
        Update: {
          assigned_to?: string | null
          case_id?: string
          completed_at?: string | null
          created_at?: string | null
          created_by?: string
          deleted_at?: string | null
          description?: string | null
          due_date?: string | null
          firm_id?: string | null
          id?: string
          is_auto_generated?: boolean | null
          linked_hearing_id?: string | null
          position?: number
          priority?: string
          stage?: string
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "strategy_tasks_assigned_to_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "strategy_tasks_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "strategy_tasks_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "strategy_tasks_linked_hearing_id_fkey"
            columns: ["linked_hearing_id"]
            isOneToOne: false
            referencedRelation: "hearings"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_notifications: {
        Row: {
          body: string
          case_id: string | null
          created_at: string | null
          id: string
          is_sent: boolean | null
          payload: Json | null
          title: string
          user_id: string | null
        }
        Insert: {
          body: string
          case_id?: string | null
          created_at?: string | null
          id?: string
          is_sent?: boolean | null
          payload?: Json | null
          title: string
          user_id?: string | null
        }
        Update: {
          body?: string
          case_id?: string | null
          created_at?: string | null
          id?: string
          is_sent?: boolean | null
          payload?: Json | null
          title?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sync_notifications_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
      task_activity_log: {
        Row: {
          action: string
          created_at: string | null
          id: string
          new_value: string | null
          old_value: string | null
          task_id: string
          user_id: string
        }
        Insert: {
          action: string
          created_at?: string | null
          id?: string
          new_value?: string | null
          old_value?: string | null
          task_id: string
          user_id: string
        }
        Update: {
          action?: string
          created_at?: string | null
          id?: string
          new_value?: string | null
          old_value?: string | null
          task_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_activity_log_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "strategy_tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_activity_log_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      task_attachments: {
        Row: {
          created_at: string | null
          file_name: string
          file_size: number | null
          file_url: string
          id: string
          mime_type: string | null
          task_id: string
          uploaded_by: string
        }
        Insert: {
          created_at?: string | null
          file_name: string
          file_size?: number | null
          file_url: string
          id?: string
          mime_type?: string | null
          task_id: string
          uploaded_by: string
        }
        Update: {
          created_at?: string | null
          file_name?: string
          file_size?: number | null
          file_url?: string
          id?: string
          mime_type?: string | null
          task_id?: string
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_attachments_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "strategy_tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_attachments_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      task_comments: {
        Row: {
          content: string
          created_at: string | null
          id: string
          task_id: string
          user_id: string
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          task_id: string
          user_id: string
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          task_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_comments_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "strategy_tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_comments_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          created_at: string | null
          created_by: string | null
          id: string
          is_completed: boolean | null
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          id?: string
          is_completed?: boolean | null
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          id?: string
          is_completed?: boolean | null
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      user_feedback: {
        Row: {
          admin_notes: string | null
          app_version: string | null
          created_at: string | null
          description: string
          device_info: string | null
          feedback_type: string
          id: string
          resolved_at: string | null
          screen_name: string | null
          severity: string | null
          status: string | null
          title: string
          user_email: string | null
          user_id: string | null
          user_name: string | null
        }
        Insert: {
          admin_notes?: string | null
          app_version?: string | null
          created_at?: string | null
          description: string
          device_info?: string | null
          feedback_type: string
          id?: string
          resolved_at?: string | null
          screen_name?: string | null
          severity?: string | null
          status?: string | null
          title: string
          user_email?: string | null
          user_id?: string | null
          user_name?: string | null
        }
        Update: {
          admin_notes?: string | null
          app_version?: string | null
          created_at?: string | null
          description?: string
          device_info?: string | null
          feedback_type?: string
          id?: string
          resolved_at?: string | null
          screen_name?: string | null
          severity?: string | null
          status?: string | null
          title?: string
          user_email?: string | null
          user_id?: string | null
          user_name?: string | null
        }
        Relationships: []
      }
      witness_examination_notes: {
        Row: {
          case_id: string | null
          created_at: string | null
          created_by: string | null
          id: string
          notes: string | null
          updated_at: string | null
          witness_name: string
          witness_tag: string | null
        }
        Insert: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          notes?: string | null
          updated_at?: string | null
          witness_name: string
          witness_tag?: string | null
        }
        Update: {
          case_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          notes?: string | null
          updated_at?: string | null
          witness_name?: string
          witness_tag?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "witness_examination_notes_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "cases"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_firm_invitation: {
        Args: { p_invitation_id: string }
        Returns: Json
      }
      admin_activity: {
        Args: {
          p_action?: string
          p_before?: string
          p_entity?: string
          p_limit?: number
          p_user_id?: string
        }
        Returns: Json
      }
      admin_activity_filters: { Args: never; Returns: Json }
      admin_is_admin: { Args: { p_user_id: string }; Returns: boolean }
      admin_overview: { Args: never; Returns: Json }
      admin_revoke_sessions: {
        Args: { p_admin_id: string; p_user_id: string }
        Returns: Json
      }
      admin_scrub_details: { Args: { p_details: Json }; Returns: Json }
      admin_set_account_disabled: {
        Args: { p_admin_id: string; p_disabled: boolean; p_user_id: string }
        Returns: Json
      }
      admin_user_detail: { Args: { p_user_id: string }; Returns: Json }
      admin_user_list: { Args: never; Returns: Json }
      bar_enrolment_key: { Args: { p_value: string }; Returns: string }
      bar_mobile_key: { Args: { p_value: string }; Returns: string }
      bar_roll_progress: { Args: { p_association_id: string }; Returns: Json }
      case_court_key: { Args: { p_value: string }; Returns: string }
      case_number_key: { Args: { p_value: string }; Returns: string }
      case_title_key: { Args: { p_value: string }; Returns: string }
      claim_bar_membership: {
        Args: { p_identifier: string; p_invite_code: string }
        Returns: Json
      }
      detach_member_from_firm: {
        Args: { p_member: string; p_notify_body: string; p_owner: string }
        Returns: undefined
      }
      find_conflicting_cases: {
        Args: {
          p_case_number: string
          p_case_title: string
          p_court_name: string
          p_exclude_id?: string
        }
        Returns: {
          case_number: string
          case_title: string
          court_name: string
          id: string
          match_type: string
        }[]
      }
      find_profile_id_by_email: { Args: { p_email: string }; Returns: string }
      generate_bar_receipt_number: {
        Args: { p_association_id: string }
        Returns: string
      }
      get_association_invite_code: {
        Args: { p_association_id: string }
        Returns: string
      }
      get_my_profile: {
        Args: never
        Returns: {
          avatar_url: string | null
          bar_association_id: string | null
          created_at: string | null
          current_period_end: string | null
          email: string | null
          firm_id: string | null
          full_name: string | null
          id: string
          is_admin: boolean | null
          is_public_directory_enabled: boolean | null
          last_seen_at: string | null
          mobile_number: string | null
          office_address: string | null
          practice_district: string | null
          practice_state: string | null
          registration_number: string | null
          subscription_tier: string | null
          trial_ends_at: string | null
          updated_at: string | null
          user_role: string
        }[]
        SetofOptions: {
          from: "*"
          to: "profiles"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_my_senior_firms: { Args: never; Returns: Json }
      get_pg_trigger_secret: { Args: never; Returns: string }
      get_profiles: {
        Args: { p_ids: string[] }
        Returns: {
          avatar_url: string
          email: string
          full_name: string
          id: string
          last_seen_at: string
          mobile_number: string
          office_address: string
          practice_district: string
          practice_state: string
          registration_number: string
          subscription_tier: string
          user_role: string
        }[]
      }
      is_association_admin: {
        Args: { p_association_id: string; p_user_id: string }
        Returns: boolean
      }
      is_association_member: {
        Args: { p_association_id: string; p_user_id: string }
        Returns: boolean
      }
      is_platform_admin: { Args: never; Returns: boolean }
      leave_firm_team: { Args: { p_owner_id?: string }; Returns: number }
      match_legal_documents: {
        Args: {
          filter_source_type?: string
          match_count?: number
          match_threshold?: number
          query_embedding: string
        }
        Returns: {
          content: string
          id: string
          metadata: Json
          similarity: number
          source_ref: string
          source_type: string
        }[]
      }
      record_admin_action: {
        Args: {
          p_action: string
          p_admin_id: string
          p_details?: Json
          p_entity: string
          p_entity_id?: string
        }
        Returns: undefined
      }
      record_notification: {
        Args: {
          p_body?: string
          p_dedupe_key?: string
          p_payload?: Json
          p_route?: string
          p_title: string
          p_type: string
          p_user_id: string
        }
        Returns: undefined
      }
      search_advocate_directory: {
        Args: { p_district?: string; p_query?: string; p_state?: string }
        Returns: {
          avatar_url: string
          email: string
          full_name: string
          id: string
          mobile_number: string
          office_address: string
          practice_district: string
          practice_state: string
          registration_number: string
        }[]
      }
      trigger_bar_push: {
        Args: { p_kind: string; p_row: Json }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
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
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
