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
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      ai_usage: {
        Row: {
          cache_hit_tokens: number
          completion_tokens: number
          cost_usd_estimate: number
          created_at: string
          id: string
          job_id: string | null
          model: string
          prompt_tokens: number
          provider: string
        }
        Insert: {
          cache_hit_tokens?: number
          completion_tokens?: number
          cost_usd_estimate?: number
          created_at?: string
          id?: string
          job_id?: string | null
          model: string
          prompt_tokens?: number
          provider: string
        }
        Update: {
          cache_hit_tokens?: number
          completion_tokens?: number
          cost_usd_estimate?: number
          created_at?: string
          id?: string
          job_id?: string | null
          model?: string
          prompt_tokens?: number
          provider?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_usage_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "jobs"
            referencedColumns: ["id"]
          },
        ]
      }
      attempts: {
        Row: {
          answered_at: string
          id: string
          is_correct: boolean
          question_id: string
          user_id: string
        }
        Insert: {
          answered_at?: string
          id?: string
          is_correct: boolean
          question_id: string
          user_id: string
        }
        Update: {
          answered_at?: string
          id?: string
          is_correct?: boolean
          question_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attempts_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chapters: {
        Row: {
          course_id: string
          created_at: string
          embedding: string | null
          id: string
          index: number
          text: string
          title: string
          token_count: number | null
        }
        Insert: {
          course_id: string
          created_at?: string
          embedding?: string | null
          id?: string
          index: number
          text: string
          title: string
          token_count?: number | null
        }
        Update: {
          course_id?: string
          created_at?: string
          embedding?: string | null
          id?: string
          index?: number
          text?: string
          title?: string
          token_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "chapters_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "course_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chapters_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
        ]
      }
      corrections: {
        Row: {
          course_id: string | null
          created_at: string
          feedback: Json | null
          grade: number | null
          id: string
          max_grade: number | null
          model_used: string | null
          rubric: Json | null
          status: Database["public"]["Enums"]["correction_status"]
          storage_paths: Json
          user_id: string
        }
        Insert: {
          course_id?: string | null
          created_at?: string
          feedback?: Json | null
          grade?: number | null
          id?: string
          max_grade?: number | null
          model_used?: string | null
          rubric?: Json | null
          status?: Database["public"]["Enums"]["correction_status"]
          storage_paths?: Json
          user_id: string
        }
        Update: {
          course_id?: string | null
          created_at?: string
          feedback?: Json | null
          grade?: number | null
          id?: string
          max_grade?: number | null
          model_used?: string | null
          rubric?: Json | null
          status?: Database["public"]["Enums"]["correction_status"]
          storage_paths?: Json
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "corrections_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "course_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "corrections_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "corrections_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      courses: {
        Row: {
          created_at: string
          exam_date: string | null
          file_hash: string
          id: string
          is_demo: boolean
          owner_id: string | null
          page_count: number | null
          shared_with_faculty: boolean
          status: Database["public"]["Enums"]["course_status"]
          storage_path: string
          subject_id: string | null
          title: string
        }
        Insert: {
          created_at?: string
          exam_date?: string | null
          file_hash: string
          id?: string
          is_demo?: boolean
          owner_id?: string | null
          page_count?: number | null
          shared_with_faculty?: boolean
          status?: Database["public"]["Enums"]["course_status"]
          storage_path: string
          subject_id?: string | null
          title: string
        }
        Update: {
          created_at?: string
          exam_date?: string | null
          file_hash?: string
          id?: string
          is_demo?: boolean
          owner_id?: string | null
          page_count?: number | null
          shared_with_faculty?: boolean
          status?: Database["public"]["Enums"]["course_status"]
          storage_path?: string
          subject_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "courses_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courses_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subject_stats"
            referencedColumns: ["subject_id"]
          },
          {
            foreignKeyName: "courses_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_activity: {
        Row: {
          correct_answers: number
          created_at: string
          day: string
          is_validated: boolean
          questions_answered: number
          user_id: string
          xp_earned: number
        }
        Insert: {
          correct_answers?: number
          created_at?: string
          day: string
          is_validated?: boolean
          questions_answered?: number
          user_id: string
          xp_earned?: number
        }
        Update: {
          correct_answers?: number
          created_at?: string
          day?: string
          is_validated?: boolean
          questions_answered?: number
          user_id?: string
          xp_earned?: number
        }
        Relationships: [
          {
            foreignKeyName: "daily_activity_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      faculties: {
        Row: {
          code: string
          created_at: string
          id: string
          name: string
          university_id: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          name: string
          university_id: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          name?: string
          university_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "faculties_university_id_fkey"
            columns: ["university_id"]
            isOneToOne: false
            referencedRelation: "universities"
            referencedColumns: ["id"]
          },
        ]
      }
      flashcards: {
        Row: {
          back: string
          chapter_id: string
          created_at: string
          front: string
          id: string
        }
        Insert: {
          back: string
          chapter_id: string
          created_at?: string
          front: string
          id?: string
        }
        Update: {
          back?: string
          chapter_id?: string
          created_at?: string
          front?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "flashcards_chapter_id_fkey"
            columns: ["chapter_id"]
            isOneToOne: false
            referencedRelation: "chapter_stats"
            referencedColumns: ["chapter_id"]
          },
          {
            foreignKeyName: "flashcards_chapter_id_fkey"
            columns: ["chapter_id"]
            isOneToOne: false
            referencedRelation: "chapters"
            referencedColumns: ["id"]
          },
        ]
      }
      jobs: {
        Row: {
          attempts: number
          created_at: string
          finished_at: string | null
          id: string
          last_error: string | null
          payload: Json
          run_after: string
          started_at: string | null
          status: Database["public"]["Enums"]["job_status"]
          type: Database["public"]["Enums"]["job_type"]
        }
        Insert: {
          attempts?: number
          created_at?: string
          finished_at?: string | null
          id?: string
          last_error?: string | null
          payload?: Json
          run_after?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["job_status"]
          type: Database["public"]["Enums"]["job_type"]
        }
        Update: {
          attempts?: number
          created_at?: string
          finished_at?: string | null
          id?: string
          last_error?: string | null
          payload?: Json
          run_after?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["job_status"]
          type?: Database["public"]["Enums"]["job_type"]
        }
        Relationships: []
      }
      packs: {
        Row: {
          active_from: string
          active_to: string | null
          code: Database["public"]["Enums"]["pack_code"]
          corrections_included: number
          created_at: string
          description: string | null
          duration_days: number
          label: string
          price_fcfa: number
          subjects_limit: number | null
        }
        Insert: {
          active_from?: string
          active_to?: string | null
          code: Database["public"]["Enums"]["pack_code"]
          corrections_included: number
          created_at?: string
          description?: string | null
          duration_days: number
          label: string
          price_fcfa: number
          subjects_limit?: number | null
        }
        Update: {
          active_from?: string
          active_to?: string | null
          code?: Database["public"]["Enums"]["pack_code"]
          corrections_included?: number
          created_at?: string
          description?: string | null
          duration_days?: number
          label?: string
          price_fcfa?: number
          subjects_limit?: number | null
        }
        Relationships: []
      }
      payments: {
        Row: {
          amount_fcfa: number
          created_at: string
          id: string
          operator: string | null
          pack_code: Database["public"]["Enums"]["pack_code"]
          phone: string | null
          provider: string
          provider_ref: string | null
          raw: Json | null
          status: Database["public"]["Enums"]["payment_status"]
          user_id: string
        }
        Insert: {
          amount_fcfa: number
          created_at?: string
          id?: string
          operator?: string | null
          pack_code: Database["public"]["Enums"]["pack_code"]
          phone?: string | null
          provider: string
          provider_ref?: string | null
          raw?: Json | null
          status?: Database["public"]["Enums"]["payment_status"]
          user_id: string
        }
        Update: {
          amount_fcfa?: number
          created_at?: string
          id?: string
          operator?: string | null
          pack_code?: Database["public"]["Enums"]["pack_code"]
          phone?: string | null
          provider?: string
          provider_ref?: string | null
          raw?: Json | null
          status?: Database["public"]["Enums"]["payment_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_pack_code_fkey"
            columns: ["pack_code"]
            isOneToOne: false
            referencedRelation: "packs"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "payments_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_key: string | null
          created_at: string
          current_streak: number
          faculty_id: string | null
          first_name: string | null
          id: string
          is_ambassador: boolean
          last_validated_on: string | null
          longest_streak: number
          phone: string | null
          referral_code: string
          referred_by: string | null
          student_card_hash: string | null
          study_year: number | null
          university_id: string | null
          verification_status: Database["public"]["Enums"]["verification_status"]
          verified_until: string | null
          xp_total: number
        }
        Insert: {
          avatar_key?: string | null
          created_at?: string
          current_streak?: number
          faculty_id?: string | null
          first_name?: string | null
          id: string
          is_ambassador?: boolean
          last_validated_on?: string | null
          longest_streak?: number
          phone?: string | null
          referral_code?: string
          referred_by?: string | null
          student_card_hash?: string | null
          study_year?: number | null
          university_id?: string | null
          verification_status?: Database["public"]["Enums"]["verification_status"]
          verified_until?: string | null
          xp_total?: number
        }
        Update: {
          avatar_key?: string | null
          created_at?: string
          current_streak?: number
          faculty_id?: string | null
          first_name?: string | null
          id?: string
          is_ambassador?: boolean
          last_validated_on?: string | null
          longest_streak?: number
          phone?: string | null
          referral_code?: string
          referred_by?: string | null
          student_card_hash?: string | null
          study_year?: number | null
          university_id?: string | null
          verification_status?: Database["public"]["Enums"]["verification_status"]
          verified_until?: string | null
          xp_total?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_faculty_id_fkey"
            columns: ["faculty_id"]
            isOneToOne: false
            referencedRelation: "faculties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_referred_by_fkey"
            columns: ["referred_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_university_id_fkey"
            columns: ["university_id"]
            isOneToOne: false
            referencedRelation: "universities"
            referencedColumns: ["id"]
          },
        ]
      }
      questions: {
        Row: {
          answer: string
          chapter_id: string
          created_at: string
          explanation: string | null
          id: string
          options: Json | null
          probability: Database["public"]["Enums"]["question_probability"]
          statement: string
          type: Database["public"]["Enums"]["question_type"]
        }
        Insert: {
          answer: string
          chapter_id: string
          created_at?: string
          explanation?: string | null
          id?: string
          options?: Json | null
          probability?: Database["public"]["Enums"]["question_probability"]
          statement: string
          type: Database["public"]["Enums"]["question_type"]
        }
        Update: {
          answer?: string
          chapter_id?: string
          created_at?: string
          explanation?: string | null
          id?: string
          options?: Json | null
          probability?: Database["public"]["Enums"]["question_probability"]
          statement?: string
          type?: Database["public"]["Enums"]["question_type"]
        }
        Relationships: [
          {
            foreignKeyName: "questions_chapter_id_fkey"
            columns: ["chapter_id"]
            isOneToOne: false
            referencedRelation: "chapter_stats"
            referencedColumns: ["chapter_id"]
          },
          {
            foreignKeyName: "questions_chapter_id_fkey"
            columns: ["chapter_id"]
            isOneToOne: false
            referencedRelation: "chapters"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          commission_rate: number
          created_at: string
          expires_at: string | null
          first_payment_at: string | null
          id: string
          referred_id: string
          referrer_id: string
        }
        Insert: {
          commission_rate: number
          created_at?: string
          expires_at?: string | null
          first_payment_at?: string | null
          id?: string
          referred_id: string
          referrer_id: string
        }
        Update: {
          commission_rate?: number
          created_at?: string
          expires_at?: string | null
          first_payment_at?: string | null
          id?: string
          referred_id?: string
          referrer_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referrals_referred_id_fkey"
            columns: ["referred_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      subjects: {
        Row: {
          created_at: string
          faculty_id: string
          id: string
          name: string
          study_year: number | null
        }
        Insert: {
          created_at?: string
          faculty_id: string
          id?: string
          name: string
          study_year?: number | null
        }
        Update: {
          created_at?: string
          faculty_id?: string
          id?: string
          name?: string
          study_year?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "subjects_faculty_id_fkey"
            columns: ["faculty_id"]
            isOneToOne: false
            referencedRelation: "faculties"
            referencedColumns: ["id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          corrections_left: number
          created_at: string
          ends_at: string
          id: string
          pack_code: Database["public"]["Enums"]["pack_code"]
          payment_id: string | null
          source: Database["public"]["Enums"]["subscription_source"]
          starts_at: string
          user_id: string
        }
        Insert: {
          corrections_left?: number
          created_at?: string
          ends_at: string
          id?: string
          pack_code: Database["public"]["Enums"]["pack_code"]
          payment_id?: string | null
          source: Database["public"]["Enums"]["subscription_source"]
          starts_at?: string
          user_id: string
        }
        Update: {
          corrections_left?: number
          created_at?: string
          ends_at?: string
          id?: string
          pack_code?: Database["public"]["Enums"]["pack_code"]
          payment_id?: string | null
          source?: Database["public"]["Enums"]["subscription_source"]
          starts_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_pack_code_fkey"
            columns: ["pack_code"]
            isOneToOne: false
            referencedRelation: "packs"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "subscriptions_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      universities: {
        Row: {
          city: string | null
          code: string
          country_code: string
          created_at: string
          id: string
          name: string
        }
        Insert: {
          city?: string | null
          code: string
          country_code?: string
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          city?: string | null
          code?: string
          country_code?: string
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      wallet_ledger: {
        Row: {
          amount_fcfa: number
          created_at: string
          id: string
          note: string | null
          reference_id: string | null
          type: Database["public"]["Enums"]["ledger_entry_type"]
          user_id: string
        }
        Insert: {
          amount_fcfa: number
          created_at?: string
          id?: string
          note?: string | null
          reference_id?: string | null
          type: Database["public"]["Enums"]["ledger_entry_type"]
          user_id: string
        }
        Update: {
          amount_fcfa?: number
          created_at?: string
          id?: string
          note?: string | null
          reference_id?: string | null
          type?: Database["public"]["Enums"]["ledger_entry_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_ledger_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      withdrawals: {
        Row: {
          amount_fcfa: number
          failure_reason: string | null
          id: string
          operator: string
          paid_at: string | null
          phone: string
          requested_at: string
          status: Database["public"]["Enums"]["withdrawal_status"]
          user_id: string
        }
        Insert: {
          amount_fcfa: number
          failure_reason?: string | null
          id?: string
          operator: string
          paid_at?: string | null
          phone: string
          requested_at?: string
          status?: Database["public"]["Enums"]["withdrawal_status"]
          user_id: string
        }
        Update: {
          amount_fcfa?: number
          failure_reason?: string | null
          id?: string
          operator?: string
          paid_at?: string | null
          phone?: string
          requested_at?: string
          status?: Database["public"]["Enums"]["withdrawal_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "withdrawals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      xp_events: {
        Row: {
          amount: number
          created_at: string
          id: string
          reason: Database["public"]["Enums"]["xp_reason"]
          reference_id: string | null
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          reason: Database["public"]["Enums"]["xp_reason"]
          reference_id?: string | null
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          reason?: Database["public"]["Enums"]["xp_reason"]
          reference_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "xp_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      active_subscriptions: {
        Row: {
          corrections_left: number | null
          created_at: string | null
          days_left: number | null
          ends_at: string | null
          id: string | null
          pack_code: Database["public"]["Enums"]["pack_code"] | null
          pack_label: string | null
          payment_id: string | null
          source: Database["public"]["Enums"]["subscription_source"] | null
          starts_at: string | null
          subjects_limit: number | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_pack_code_fkey"
            columns: ["pack_code"]
            isOneToOne: false
            referencedRelation: "packs"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "subscriptions_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chapter_stats: {
        Row: {
          chapter_id: string | null
          course_id: string | null
          index: number | null
          is_weak: boolean | null
          nb_fiches: number | null
          nb_justes: number | null
          nb_questions: number | null
          nb_tentees: number | null
          taux: number | null
          title: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chapters_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "course_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chapters_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
        ]
      }
      course_overview: {
        Row: {
          created_at: string | null
          exam_date: string | null
          faculty_id: string | null
          id: string | null
          is_demo: boolean | null
          nb_chapitres: number | null
          nb_fiches: number | null
          nb_questions: number | null
          nb_tentees: number | null
          owner_id: string | null
          page_count: number | null
          shared_with_faculty: boolean | null
          status: Database["public"]["Enums"]["course_status"] | null
          subject_id: string | null
          subject_name: string | null
          title: string | null
        }
        Relationships: [
          {
            foreignKeyName: "courses_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courses_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subject_stats"
            referencedColumns: ["subject_id"]
          },
          {
            foreignKeyName: "courses_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subjects_faculty_id_fkey"
            columns: ["faculty_id"]
            isOneToOne: false
            referencedRelation: "faculties"
            referencedColumns: ["id"]
          },
        ]
      }
      subject_stats: {
        Row: {
          attempts_total: number | null
          average_score: number | null
          correct_count: number | null
          faculty_id: string | null
          is_weak: boolean | null
          last_answered_at: string | null
          questions_answered: number | null
          subject_id: string | null
          subject_name: string | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "attempts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subjects_faculty_id_fkey"
            columns: ["faculty_id"]
            isOneToOne: false
            referencedRelation: "faculties"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      can_read_course: { Args: { target: string }; Returns: boolean }
      claim_jobs: {
        Args: { batch_size?: number; stale_after?: string }
        Returns: {
          attempts: number
          created_at: string
          finished_at: string | null
          id: string
          last_error: string | null
          payload: Json
          run_after: string
          started_at: string | null
          status: Database["public"]["Enums"]["job_status"]
          type: Database["public"]["Enums"]["job_type"]
        }[]
        SetofOptions: {
          from: "*"
          to: "jobs"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      current_faculty_id: { Args: never; Returns: string }
      daily_goal: { Args: never; Returns: number }
      generate_referral_code: { Args: never; Returns: string }
      job_peut_demarrer: {
        Args: {
          at_time?: string
          created: string
          job_type: Database["public"]["Enums"]["job_type"]
        }
        Returns: boolean
      }
      recompute_xp_total: { Args: { target: string }; Returns: number }
      refresh_streak: { Args: { target: string }; Returns: undefined }
      streak_week: {
        Args: { anchor?: string }
        Returns: {
          day: string
          is_today: boolean
          is_validated: boolean
          questions_answered: number
          weekday: number
          xp_earned: number
        }[]
      }
      wallet_balance: { Args: never; Returns: number }
    }
    Enums: {
      correction_status: "pending" | "processing" | "ready" | "failed"
      course_status: "uploaded" | "processing" | "ready" | "failed"
      job_status: "queued" | "running" | "done" | "failed"
      job_type:
        | "ingest_course"
        | "generate_questions"
        | "correct_copy"
        | "verify_card"
        | "notify"
      ledger_entry_type:
        | "referral_commission"
        | "sale"
        | "withdrawal"
        | "adjustment"
      pack_code:
        | "decouverte"
        | "controle"
        | "partiel"
        | "semestre"
        | "rattrapage"
      payment_status: "pending" | "success" | "failed"
      question_probability: "high" | "medium" | "low"
      question_type: "mcq" | "open"
      subscription_source: "payment" | "class_purchase" | "bonus"
      verification_status: "none" | "pending" | "verified" | "rejected"
      withdrawal_status: "requested" | "processing" | "paid" | "rejected"
      xp_reason:
        | "correct_answer"
        | "quiz_completed"
        | "daily_goal"
        | "streak_bonus"
        | "course_added"
        | "correction_done"
        | "referral"
        | "adjustment"
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
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      correction_status: ["pending", "processing", "ready", "failed"],
      course_status: ["uploaded", "processing", "ready", "failed"],
      job_status: ["queued", "running", "done", "failed"],
      job_type: [
        "ingest_course",
        "generate_questions",
        "correct_copy",
        "verify_card",
        "notify",
      ],
      ledger_entry_type: [
        "referral_commission",
        "sale",
        "withdrawal",
        "adjustment",
      ],
      pack_code: [
        "decouverte",
        "controle",
        "partiel",
        "semestre",
        "rattrapage",
      ],
      payment_status: ["pending", "success", "failed"],
      question_probability: ["high", "medium", "low"],
      question_type: ["mcq", "open"],
      subscription_source: ["payment", "class_purchase", "bonus"],
      verification_status: ["none", "pending", "verified", "rejected"],
      withdrawal_status: ["requested", "processing", "paid", "rejected"],
      xp_reason: [
        "correct_answer",
        "quiz_completed",
        "daily_goal",
        "streak_bonus",
        "course_added",
        "correction_done",
        "referral",
        "adjustment",
      ],
    },
  },
} as const
