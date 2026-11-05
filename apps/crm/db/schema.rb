# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_04_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.string "kind", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.bigint "owner_id", null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "due_at"
    t.datetime "completed_at"
    t.string "outcome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inbox_item_id"
    t.string "rule_key"
    t.index ["inbox_item_id", "rule_key"], name: "index_activities_on_inbox_item_and_rule_key", unique: true, where: "(rule_key IS NOT NULL)"
    t.index ["inbox_item_id"], name: "index_activities_on_inbox_item_id"
    t.index ["owner_id", "completed_at", "due_at"], name: "index_activities_on_owner_id_and_completed_at_and_due_at"
    t.index ["owner_id"], name: "index_activities_on_owner_id"
    t.index ["subject_type", "subject_id"], name: "index_activities_on_subject"
    t.check_constraint "kind::text = ANY (ARRAY['call'::character varying::text, 'meeting'::character varying::text, 'task'::character varying::text, 'follow_up'::character varying::text, 'reminder'::character varying::text, 'note'::character varying::text])", name: "activities_kind"
  end

  create_table "agent_runs", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "status", default: "running", null: false
    t.string "trigger", default: "manual", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.string "source_key"
    t.string "source_url"
    t.text "summary"
    t.integer "leads_detected", default: 0, null: false
    t.integer "duplicates", default: 0, null: false
    t.integer "errors_count", default: 0, null: false
    t.jsonb "error_messages", default: [], null: false
    t.integer "pending_approvals", default: 0, null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.bigint "triggered_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "started_at"], name: "index_agent_runs_on_agent_id_and_started_at"
    t.index ["agent_id"], name: "index_agent_runs_on_agent_id"
    t.index ["status"], name: "index_agent_runs_on_status"
    t.index ["subject_type", "subject_id"], name: "index_agent_runs_on_subject"
    t.index ["triggered_by_id"], name: "index_agent_runs_on_triggered_by_id"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "agent_runs_status"
    t.check_constraint "trigger::text = ANY (ARRAY['manual'::character varying, 'scheduled'::character varying, 'event'::character varying, 'api'::character varying]::text[])", name: "agent_runs_trigger"
  end

  create_table "agents", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "area", null: false
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.string "execution_mode", default: "manual", null: false
    t.string "schedule"
    t.jsonb "allowed_actions", default: [], null: false
    t.string "implemented_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_agents_on_key", unique: true
    t.check_constraint "area::text = ANY (ARRAY['prospect_ai'::character varying, 'sales_intelligence'::character varying, 'sales_agent'::character varying, 'relationship_hub'::character varying]::text[])", name: "agents_area"
    t.check_constraint "execution_mode::text = ANY (ARRAY['manual'::character varying, 'scheduled'::character varying]::text[])", name: "agents_execution_mode"
    t.check_constraint "jsonb_typeof(allowed_actions) = 'array'::text AND NOT allowed_actions ?| ARRAY['send_proposals'::text, 'contact_clients'::text, 'commit_prices'::text, 'hire_services'::text, 'spend_money'::text]", name: "agents_no_forbidden_actions"
  end

  create_table "ai_analyses", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "kind", null: false
    t.string "provider", null: false
    t.string "engine_version"
    t.jsonb "output", default: {}, null: false
    t.string "status", default: "pending_review", null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewed_by_id"], name: "index_ai_analyses_on_reviewed_by_id"
    t.index ["subject_type", "subject_id"], name: "index_ai_analyses_on_subject"
    t.check_constraint "status::text = ANY (ARRAY['pending_review'::character varying::text, 'accepted'::character varying::text, 'rejected'::character varying::text, 'superseded'::character varying::text])", name: "ai_analyses_status"
  end

  create_table "api_clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.string "scopes", default: [], null: false, array: true
    t.boolean "active", default: true, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_api_clients_on_name", unique: true
    t.index ["token_digest"], name: "index_api_clients_on_token_digest", unique: true
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "inbox_item_id", null: false
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.bigint "actor_id"
    t.string "source", null: false
    t.text "reason"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_assignments_on_actor_id"
    t.index ["inbox_item_id", "ended_at"], name: "index_assignments_on_inbox_item_id_and_ended_at"
    t.index ["user_id"], name: "index_assignments_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['proposed'::character varying, 'confirmed'::character varying]::text[])", name: "assignments_kind_valid"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "changeset", default: {}, null: false
    t.string "ip_address"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.bigint "api_client_id"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["api_client_id"], name: "index_audit_logs_on_api_client_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
  end

  create_table "channels", force: :cascade do |t|
    t.string "kind", null: false
    t.string "name", null: false
    t.string "external_account_id", null: false
    t.string "status", default: "planned", null: false
    t.bigint "default_owner_id"
    t.boolean "auto_confirm", default: false, null: false
    t.boolean "auto_create_lead", default: false, null: false
    t.boolean "synthetic", default: false, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "last_event_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["default_owner_id"], name: "index_channels_on_default_owner_id"
    t.index ["kind", "external_account_id"], name: "index_channels_on_kind_and_external_account_id", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['whatsapp'::character varying, 'meta_lead_ads'::character varying, 'instagram'::character varying]::text[])", name: "channels_kind_valid"
    t.check_constraint "status::text = ANY (ARRAY['planned'::character varying, 'configured'::character varying, 'operational'::character varying, 'paused'::character varying]::text[])", name: "channels_status_valid"
  end

  create_table "commercial_thresholds", force: :cascade do |t|
    t.string "currency", limit: 3, null: false
    t.bigint "medium_from_cents", null: false
    t.bigint "high_from_cents", null: false
    t.bigint "approved_by_id"
    t.string "approval_reference", null: false
    t.datetime "approved_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_commercial_thresholds_on_approved_by_id"
    t.index ["currency"], name: "index_commercial_thresholds_on_currency", unique: true
    t.check_constraint "medium_from_cents >= 0 AND high_from_cents >= medium_from_cents", name: "commercial_thresholds_range"
  end

  create_table "companies", force: :cascade do |t|
    t.string "trade_name", null: false
    t.string "legal_name"
    t.string "sector"
    t.bigint "country_id"
    t.string "website"
    t.string "normalized_domain"
    t.bigint "owner_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_companies_on_country_id"
    t.index ["normalized_domain"], name: "index_companies_on_normalized_domain", unique: true, where: "(normalized_domain IS NOT NULL)"
    t.index ["owner_id"], name: "index_companies_on_owner_id"
    t.index ["trade_name"], name: "index_companies_on_trade_name"
  end

  create_table "company_services", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "service_id"], name: "index_company_services_on_company_id_and_service_id", unique: true
    t.index ["company_id"], name: "index_company_services_on_company_id"
    t.index ["service_id"], name: "index_company_services_on_service_id"
  end

  create_table "contact_matches", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.bigint "candidate_contact_id", null: false
    t.string "reason", null: false
    t.string "status", default: "pending", null: false
    t.bigint "decided_by_id"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_contact_id"], name: "index_contact_matches_on_candidate_contact_id"
    t.index ["contact_id", "candidate_contact_id"], name: "index_contact_matches_on_contact_id_and_candidate_contact_id", unique: true
    t.index ["contact_id"], name: "index_contact_matches_on_contact_id"
    t.index ["decided_by_id"], name: "index_contact_matches_on_decided_by_id"
    t.check_constraint "contact_id <> candidate_contact_id", name: "contact_matches_distinct"
    t.check_constraint "reason::text = ANY (ARRAY['same_phone'::character varying, 'same_email'::character varying]::text[])", name: "contact_matches_reason_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'reverted'::character varying]::text[])", name: "contact_matches_status_valid"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "name"
    t.string "phone_e164"
    t.string "email"
    t.bigint "company_id"
    t.bigint "primary_contact_id"
    t.string "consent_source"
    t.datetime "consent_at"
    t.boolean "do_not_contact", default: false, null: false
    t.datetime "anonymized_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_contacts_on_company_id"
    t.index ["email"], name: "index_contacts_on_email"
    t.index ["phone_e164"], name: "index_contacts_on_phone_e164"
    t.index ["primary_contact_id"], name: "index_contacts_on_primary_contact_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.bigint "external_identity_id", null: false
    t.bigint "contact_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "last_inbound_at"
    t.datetime "window_expires_at"
    t.datetime "reopened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_conversations_on_channel_id"
    t.index ["contact_id"], name: "index_conversations_on_contact_id"
    t.index ["external_identity_id"], name: "index_conversations_on_external_identity_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'closed'::character varying]::text[])", name: "conversations_status_valid"
  end

  create_table "countries", force: :cascade do |t|
    t.string "iso2", limit: 2, null: false
    t.string "name", null: false
    t.string "default_currency", limit: 3, null: false
    t.string "locale", null: false
    t.string "timezone", null: false
    t.boolean "target_market", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
  end

  create_table "external_identities", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.bigint "contact_id", null: false
    t.string "external_id", null: false
    t.string "profile_name"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "external_id"], name: "index_external_identities_on_channel_id_and_external_id", unique: true
    t.index ["channel_id"], name: "index_external_identities_on_channel_id"
    t.index ["contact_id"], name: "index_external_identities_on_contact_id"
  end

  create_table "inbox_items", force: :cascade do |t|
    t.string "kind", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.bigint "channel_id", null: false
    t.bigint "contact_id"
    t.bigint "lead_id"
    t.string "attention_status", default: "new", null: false
    t.string "discard_reason"
    t.datetime "review_at"
    t.string "assignment_status", default: "unassigned", null: false
    t.bigint "proposed_owner_id"
    t.bigint "proposed_by_id"
    t.datetime "proposed_at"
    t.string "proposal_source"
    t.text "proposal_note"
    t.bigint "confirmed_owner_id"
    t.bigint "confirmed_by_id"
    t.datetime "confirmed_at"
    t.datetime "first_attended_at"
    t.datetime "last_activity_at", null: false
    t.text "preview"
    t.integer "reopened_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_status"], name: "index_inbox_items_pending_assignment", where: "((assignment_status)::text <> 'confirmed'::text)"
    t.index ["channel_id"], name: "index_inbox_items_on_channel_id"
    t.index ["confirmed_by_id"], name: "index_inbox_items_on_confirmed_by_id"
    t.index ["confirmed_owner_id", "attention_status"], name: "index_inbox_items_on_confirmed_owner_id_and_attention_status"
    t.index ["contact_id"], name: "index_inbox_items_on_contact_id"
    t.index ["last_activity_at", "id"], name: "index_inbox_items_on_last_activity_at_and_id", order: :desc
    t.index ["lead_id"], name: "index_inbox_items_on_lead_id"
    t.index ["proposed_by_id"], name: "index_inbox_items_on_proposed_by_id"
    t.index ["proposed_owner_id"], name: "index_inbox_items_on_proposed_owner_id"
    t.index ["subject_type", "subject_id"], name: "index_inbox_items_on_subject", unique: true
    t.index ["updated_at", "last_activity_at"], name: "index_inbox_items_on_updated_at_and_last_activity_at"
    t.check_constraint "assignment_status::text <> 'confirmed'::text OR confirmed_owner_id IS NOT NULL", name: "inbox_items_confirmed_needs_owner"
    t.check_constraint "assignment_status::text <> 'proposed'::text OR proposed_owner_id IS NOT NULL", name: "inbox_items_proposed_needs_owner"
    t.check_constraint "assignment_status::text = ANY (ARRAY['unassigned'::character varying, 'proposed'::character varying, 'confirmed'::character varying]::text[])", name: "inbox_items_assignment_status_valid"
    t.check_constraint "attention_status::text <> 'discarded'::text OR discard_reason IS NOT NULL", name: "inbox_items_discard_needs_reason"
    t.check_constraint "attention_status::text <> 'waiting_customer'::text OR review_at IS NOT NULL", name: "inbox_items_waiting_needs_review_at"
    t.check_constraint "attention_status::text = ANY (ARRAY['new'::character varying, 'in_progress'::character varying, 'waiting_customer'::character varying, 'resolved'::character varying, 'discarded'::character varying]::text[])", name: "inbox_items_attention_status_valid"
    t.check_constraint "kind::text = ANY (ARRAY['conversation'::character varying, 'form_submission'::character varying]::text[])", name: "inbox_items_kind_valid"
    t.check_constraint "proposal_source IS NULL OR (proposal_source::text = ANY (ARRAY['rule'::character varying, 'manager'::character varying]::text[]))", name: "inbox_items_proposal_source_valid"
  end

  create_table "inbox_notes", force: :cascade do |t|
    t.bigint "inbox_item_id", null: false
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_inbox_notes_on_author_id"
    t.index ["inbox_item_id", "created_at"], name: "index_inbox_notes_on_inbox_item_id_and_created_at"
  end

  create_table "inbox_operations", force: :cascade do |t|
    t.uuid "operation_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.string "request_sha256", null: false
    t.integer "response_status", null: false
    t.jsonb "response_body", default: {}, null: false
    t.integer "resulting_lock_version"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_inbox_operations_on_actor_id"
    t.index ["created_at"], name: "index_inbox_operations_on_created_at"
    t.index ["operation_id"], name: "index_inbox_operations_on_operation_id", unique: true
    t.index ["target_type", "target_id"], name: "index_inbox_operations_on_target"
  end

  create_table "ingestion_requests", force: :cascade do |t|
    t.bigint "api_client_id", null: false
    t.string "idempotency_key", null: false
    t.string "request_sha256", null: false
    t.integer "response_status", null: false
    t.jsonb "response_body", default: {}, null: false
    t.bigint "lead_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_client_id", "idempotency_key"], name: "index_ingestion_requests_on_api_client_id_and_idempotency_key", unique: true
    t.index ["api_client_id"], name: "index_ingestion_requests_on_api_client_id"
    t.index ["lead_id"], name: "index_ingestion_requests_on_lead_id"
    t.check_constraint "char_length(idempotency_key::text) >= 8 AND char_length(idempotency_key::text) <= 128", name: "ingestion_requests_key_length"
  end

  create_table "lead_evidences", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.string "kind", default: "post_excerpt", null: false
    t.string "url"
    t.text "excerpt"
    t.datetime "captured_at", null: false
    t.bigint "captured_by_id"
    t.string "content_sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["captured_by_id"], name: "index_lead_evidences_on_captured_by_id"
    t.index ["lead_id"], name: "index_lead_evidences_on_lead_id"
    t.check_constraint "char_length(excerpt) <= 2000", name: "lead_evidences_excerpt_length"
  end

  create_table "lead_form_submissions", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.string "leadgen_id", null: false
    t.string "form_id"
    t.string "form_name"
    t.string "ad_id"
    t.string "ad_name"
    t.string "campaign_id"
    t.string "campaign_name"
    t.string "platform"
    t.boolean "is_organic"
    t.string "retrieval_status", default: "pending", null: false
    t.text "retrieval_error"
    t.text "field_data"
    t.datetime "submitted_at"
    t.datetime "received_at", null: false
    t.datetime "retrieved_at"
    t.bigint "contact_id"
    t.bigint "lead_id"
    t.bigint "webhook_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_lead_form_submissions_on_channel_id"
    t.index ["contact_id"], name: "index_lead_form_submissions_on_contact_id"
    t.index ["lead_id"], name: "index_lead_form_submissions_on_lead_id"
    t.index ["leadgen_id"], name: "index_lead_form_submissions_on_leadgen_id", unique: true
    t.index ["webhook_event_id"], name: "index_lead_form_submissions_on_webhook_event_id"
    t.check_constraint "retrieval_status::text = ANY (ARRAY['pending'::character varying, 'retrieved'::character varying, 'failed'::character varying]::text[])", name: "lead_form_submissions_retrieval_status_valid"
  end

  create_table "lead_scores", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.bigint "scoring_criterion_id", null: false
    t.integer "points", null: false
    t.string "basis", null: false
    t.text "justification"
    t.string "set_by", default: "human", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id", "scoring_criterion_id"], name: "index_lead_scores_on_lead_id_and_scoring_criterion_id", unique: true
    t.index ["lead_id"], name: "index_lead_scores_on_lead_id"
    t.index ["scoring_criterion_id"], name: "index_lead_scores_on_scoring_criterion_id"
    t.check_constraint "basis::text = ANY (ARRAY['verified'::character varying::text, 'inferred'::character varying::text])", name: "lead_scores_basis"
    t.check_constraint "points >= 0", name: "lead_scores_points"
  end

  create_table "lead_services", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id", "service_id"], name: "index_lead_services_on_lead_id_and_service_id", unique: true
    t.index ["lead_id"], name: "index_lead_services_on_lead_id"
    t.index ["service_id"], name: "index_lead_services_on_service_id"
  end

  create_table "leads", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "country_id"
    t.bigint "company_id"
    t.bigint "owner_id"
    t.string "title", null: false
    t.text "need_summary"
    t.string "original_url"
    t.string "author_display_name"
    t.datetime "published_at"
    t.datetime "detected_at", null: false
    t.string "published_budget_text"
    t.string "urgency", default: "unknown", null: false
    t.string "verification_status", default: "unverified", null: false
    t.string "status", default: "new", null: false
    t.string "discard_reason"
    t.integer "score"
    t.string "score_band"
    t.integer "scoring_version"
    t.string "fingerprint", null: false
    t.string "created_via", default: "manual", null: false
    t.text "suggested_message"
    t.text "recommended_action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.boolean "published_at_verified", default: false, null: false
    t.string "contact_channel_kind"
    t.string "budget_currency", limit: 3
    t.bigint "budget_min_cents"
    t.bigint "budget_max_cents"
    t.integer "competition_count"
    t.datetime "deadline_at"
    t.boolean "listing_closed", default: false, null: false
    t.integer "estimated_hours"
    t.string "commercial_priority"
    t.integer "priority_score"
    t.decimal "priority_confidence", precision: 3, scale: 2
    t.jsonb "priority_breakdown", default: {}, null: false
    t.datetime "priority_calculated_at"
    t.boolean "synthetic", default: false, null: false
    t.bigint "contact_id"
    t.index ["commercial_priority"], name: "index_leads_on_commercial_priority"
    t.index ["company_id"], name: "index_leads_on_company_id"
    t.index ["contact_id"], name: "index_leads_on_contact_id"
    t.index ["country_id", "detected_at"], name: "index_leads_on_country_id_and_detected_at"
    t.index ["country_id"], name: "index_leads_on_country_id"
    t.index ["fingerprint"], name: "index_leads_on_fingerprint", unique: true
    t.index ["owner_id"], name: "index_leads_on_owner_id"
    t.index ["source_id", "detected_at"], name: "index_leads_on_source_id_and_detected_at"
    t.index ["source_id"], name: "index_leads_on_source_id"
    t.index ["status", "score"], name: "index_leads_on_status_and_score"
    t.index ["synthetic"], name: "index_leads_on_synthetic", where: "synthetic"
    t.check_constraint "budget_min_cents IS NULL OR budget_max_cents IS NULL OR budget_max_cents >= budget_min_cents", name: "leads_budget_range"
    t.check_constraint "commercial_priority::text = ANY (ARRAY['high'::character varying::text, 'medium'::character varying::text, 'low'::character varying::text, 'not_recommended'::character varying::text])", name: "leads_commercial_priority"
    t.check_constraint "competition_count IS NULL OR competition_count >= 0", name: "leads_competition_count"
    t.check_constraint "created_via::text = ANY (ARRAY['manual'::character varying::text, 'api'::character varying::text, 'skill'::character varying::text])", name: "leads_created_via"
    t.check_constraint "estimated_hours IS NULL OR estimated_hours > 0", name: "leads_estimated_hours"
    t.check_constraint "score IS NULL OR score >= 0 AND score <= 100", name: "leads_score"
    t.check_constraint "status::text = ANY (ARRAY['new'::character varying::text, 'researching'::character varying::text, 'qualified'::character varying::text, 'discarded'::character varying::text, 'converted'::character varying::text])", name: "leads_status"
    t.check_constraint "urgency::text = ANY (ARRAY['unknown'::character varying::text, 'low'::character varying::text, 'medium'::character varying::text, 'high'::character varying::text])", name: "leads_urgency"
    t.check_constraint "verification_status::text = ANY (ARRAY['unverified'::character varying::text, 'verified'::character varying::text, 'unreachable'::character varying::text, 'rejected'::character varying::text])", name: "leads_verification_status"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "direction", default: "in", null: false
    t.string "external_message_id", null: false
    t.string "message_kind", default: "text", null: false
    t.string "content_status", default: "ok", null: false
    t.text "body"
    t.jsonb "media", default: {}, null: false
    t.datetime "sent_at", null: false
    t.datetime "received_at", null: false
    t.bigint "webhook_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "sent_at", "id"], name: "index_messages_on_conversation_id_and_sent_at_and_id"
    t.index ["external_message_id"], name: "index_messages_on_external_message_id", unique: true
    t.index ["webhook_event_id"], name: "index_messages_on_webhook_event_id"
    t.check_constraint "content_status::text = ANY (ARRAY['ok'::character varying, 'unsupported'::character varying, 'unavailable'::character varying]::text[])", name: "messages_content_status_valid"
    t.check_constraint "direction::text = 'in'::text", name: "messages_inbound_only"
  end

  create_table "opportunities", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "company_id", null: false
    t.bigint "lead_id"
    t.bigint "pipeline_stage_id", null: false
    t.bigint "owner_id", null: false
    t.bigint "country_id"
    t.bigint "estimated_value_cents"
    t.string "currency", limit: 3
    t.date "expected_close_on"
    t.datetime "stage_changed_at", null: false
    t.datetime "won_at"
    t.datetime "lost_at"
    t.string "lost_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "contact_id"
    t.index ["company_id"], name: "index_opportunities_on_company_id"
    t.index ["contact_id"], name: "index_opportunities_on_contact_id"
    t.index ["country_id"], name: "index_opportunities_on_country_id"
    t.index ["lead_id"], name: "index_opportunities_on_lead_id", unique: true
    t.index ["owner_id"], name: "index_opportunities_on_owner_id"
    t.index ["pipeline_stage_id"], name: "index_opportunities_on_pipeline_stage_id"
    t.check_constraint "estimated_value_cents IS NULL OR currency IS NOT NULL", name: "opportunities_currency"
    t.check_constraint "estimated_value_cents IS NULL OR estimated_value_cents >= 0", name: "opportunities_value"
  end

  create_table "opportunity_services", force: :cascade do |t|
    t.bigint "opportunity_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["opportunity_id", "service_id"], name: "index_opportunity_services_on_opportunity_id_and_service_id", unique: true
    t.index ["opportunity_id"], name: "index_opportunity_services_on_opportunity_id"
    t.index ["service_id"], name: "index_opportunity_services_on_service_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "pipeline_stages", force: :cascade do |t|
    t.string "name", null: false
    t.integer "position", null: false
    t.string "kind", default: "open", null: false
    t.integer "probability", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_pipeline_stages_on_position", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['open'::character varying::text, 'won'::character varying::text, 'lost'::character varying::text])", name: "pipeline_stages_kind"
    t.check_constraint "probability >= 0 AND probability <= 100", name: "pipeline_stages_probability"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "rubric_versions", force: :cascade do |t|
    t.integer "version", null: false
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.datetime "activated_at"
    t.bigint "approved_by_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_rubric_versions_on_approved_by_id"
    t.index ["status"], name: "index_rubric_versions_single_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["version"], name: "index_rubric_versions_on_version", unique: true
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'retired'::character varying::text])", name: "rubric_versions_status"
  end

  create_table "scoring_criteria", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.integer "max_points", null: false
    t.integer "position", null: false
    t.integer "version", default: 1, null: false
    t.text "guidance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["version", "key"], name: "index_scoring_criteria_on_version_and_key", unique: true
    t.check_constraint "max_points > 0", name: "scoring_criteria_max_points"
  end

  create_table "service_rates", force: :cascade do |t|
    t.bigint "service_id", null: false
    t.bigint "country_id"
    t.string "currency", limit: 3, null: false
    t.string "unit", null: false
    t.bigint "min_cents", null: false
    t.bigint "max_cents", null: false
    t.date "valid_from", null: false
    t.date "valid_until"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.bigint "created_by_id"
    t.index ["approved_by_id"], name: "index_service_rates_on_approved_by_id"
    t.index ["country_id"], name: "index_service_rates_on_country_id"
    t.index ["created_by_id"], name: "index_service_rates_on_created_by_id"
    t.index ["service_id", "country_id", "valid_from"], name: "idx_on_service_id_country_id_valid_from_46784180d7"
    t.index ["service_id"], name: "index_service_rates_on_service_id"
    t.check_constraint "min_cents >= 0 AND max_cents >= min_cents", name: "service_rates_range"
    t.check_constraint "status::text <> 'approved'::text OR approved_by_id IS NOT NULL AND approved_at IS NOT NULL", name: "service_rates_approval"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'retired'::character varying::text])", name: "service_rates_status"
    t.check_constraint "unit::text = ANY (ARRAY['project'::character varying::text, 'hour'::character varying::text, 'month'::character varying::text])", name: "service_rates_unit"
    t.check_constraint "valid_until IS NULL OR valid_until >= valid_from", name: "service_rates_validity"
  end

  create_table "services", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value_tier", default: "medium", null: false
    t.boolean "recurring", default: false, null: false
    t.index ["key"], name: "index_services_on_key", unique: true
    t.check_constraint "value_tier::text = ANY (ARRAY['high'::character varying::text, 'medium'::character varying::text, 'low'::character varying::text])", name: "services_value_tier"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "requires_manual_capture", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_sources_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.bigint "role_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "provider", default: "meta", null: false
    t.string "object_type", null: false
    t.string "event_key", null: false
    t.bigint "channel_id"
    t.text "payload", null: false
    t.jsonb "summary", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.datetime "received_at", null: false
    t.datetime "last_enqueued_at"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_webhook_events_on_channel_id"
    t.index ["event_key"], name: "index_webhook_events_on_event_key", unique: true
    t.index ["status", "received_at"], name: "index_webhook_events_on_status_and_received_at"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processed'::character varying, 'failed'::character varying, 'ignored'::character varying]::text[])", name: "webhook_events_status_valid"
  end

  add_foreign_key "activities", "inbox_items"
  add_foreign_key "activities", "users", column: "owner_id"
  add_foreign_key "agent_runs", "agents"
  add_foreign_key "agent_runs", "users", column: "triggered_by_id"
  add_foreign_key "ai_analyses", "users", column: "reviewed_by_id"
  add_foreign_key "assignments", "inbox_items"
  add_foreign_key "assignments", "users"
  add_foreign_key "assignments", "users", column: "actor_id"
  add_foreign_key "audit_logs", "api_clients"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "channels", "users", column: "default_owner_id"
  add_foreign_key "commercial_thresholds", "users", column: "approved_by_id"
  add_foreign_key "companies", "countries"
  add_foreign_key "companies", "users", column: "owner_id"
  add_foreign_key "company_services", "companies", on_delete: :cascade
  add_foreign_key "company_services", "services"
  add_foreign_key "contact_matches", "contacts"
  add_foreign_key "contact_matches", "contacts", column: "candidate_contact_id"
  add_foreign_key "contact_matches", "users", column: "decided_by_id"
  add_foreign_key "contacts", "companies"
  add_foreign_key "contacts", "contacts", column: "primary_contact_id"
  add_foreign_key "conversations", "channels"
  add_foreign_key "conversations", "contacts"
  add_foreign_key "conversations", "external_identities"
  add_foreign_key "external_identities", "channels"
  add_foreign_key "external_identities", "contacts"
  add_foreign_key "inbox_items", "channels"
  add_foreign_key "inbox_items", "contacts"
  add_foreign_key "inbox_items", "leads"
  add_foreign_key "inbox_items", "users", column: "confirmed_by_id"
  add_foreign_key "inbox_items", "users", column: "confirmed_owner_id"
  add_foreign_key "inbox_items", "users", column: "proposed_by_id"
  add_foreign_key "inbox_items", "users", column: "proposed_owner_id"
  add_foreign_key "inbox_notes", "inbox_items"
  add_foreign_key "inbox_notes", "users", column: "author_id"
  add_foreign_key "inbox_operations", "users", column: "actor_id"
  add_foreign_key "ingestion_requests", "api_clients"
  add_foreign_key "ingestion_requests", "leads", on_delete: :nullify
  add_foreign_key "lead_evidences", "leads", on_delete: :cascade
  add_foreign_key "lead_evidences", "users", column: "captured_by_id"
  add_foreign_key "lead_form_submissions", "channels"
  add_foreign_key "lead_form_submissions", "contacts"
  add_foreign_key "lead_form_submissions", "leads"
  add_foreign_key "lead_form_submissions", "webhook_events"
  add_foreign_key "lead_scores", "leads", on_delete: :cascade
  add_foreign_key "lead_scores", "scoring_criteria"
  add_foreign_key "lead_services", "leads", on_delete: :cascade
  add_foreign_key "lead_services", "services"
  add_foreign_key "leads", "companies"
  add_foreign_key "leads", "contacts"
  add_foreign_key "leads", "countries"
  add_foreign_key "leads", "sources"
  add_foreign_key "leads", "users", column: "owner_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "webhook_events"
  add_foreign_key "opportunities", "companies"
  add_foreign_key "opportunities", "contacts"
  add_foreign_key "opportunities", "countries"
  add_foreign_key "opportunities", "leads"
  add_foreign_key "opportunities", "pipeline_stages"
  add_foreign_key "opportunities", "users", column: "owner_id"
  add_foreign_key "opportunity_services", "opportunities", on_delete: :cascade
  add_foreign_key "opportunity_services", "services"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "rubric_versions", "users", column: "approved_by_id"
  add_foreign_key "service_rates", "countries"
  add_foreign_key "service_rates", "services"
  add_foreign_key "service_rates", "users", column: "approved_by_id"
  add_foreign_key "service_rates", "users", column: "created_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "roles"
  add_foreign_key "webhook_events", "channels"
end
