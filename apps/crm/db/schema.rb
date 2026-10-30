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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_210000) do
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
    t.index ["owner_id", "completed_at", "due_at"], name: "index_activities_on_owner_id_and_completed_at_and_due_at"
    t.index ["owner_id"], name: "index_activities_on_owner_id"
    t.index ["subject_type", "subject_id"], name: "index_activities_on_subject"
    t.check_constraint "kind::text = ANY (ARRAY['call'::character varying, 'meeting'::character varying, 'task'::character varying, 'follow_up'::character varying, 'reminder'::character varying, 'note'::character varying]::text[])", name: "activities_kind"
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
    t.check_constraint "status::text = ANY (ARRAY['pending_review'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'superseded'::character varying]::text[])", name: "ai_analyses_status"
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
    t.check_constraint "basis::text = ANY (ARRAY['verified'::character varying, 'inferred'::character varying]::text[])", name: "lead_scores_basis"
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
    t.index ["company_id"], name: "index_leads_on_company_id"
    t.index ["country_id", "detected_at"], name: "index_leads_on_country_id_and_detected_at"
    t.index ["country_id"], name: "index_leads_on_country_id"
    t.index ["fingerprint"], name: "index_leads_on_fingerprint", unique: true
    t.index ["owner_id"], name: "index_leads_on_owner_id"
    t.index ["source_id", "detected_at"], name: "index_leads_on_source_id_and_detected_at"
    t.index ["source_id"], name: "index_leads_on_source_id"
    t.index ["status", "score"], name: "index_leads_on_status_and_score"
    t.check_constraint "created_via::text = ANY (ARRAY['manual'::character varying, 'api'::character varying, 'skill'::character varying]::text[])", name: "leads_created_via"
    t.check_constraint "score IS NULL OR score >= 0 AND score <= 100", name: "leads_score"
    t.check_constraint "status::text = ANY (ARRAY['new'::character varying, 'researching'::character varying, 'qualified'::character varying, 'discarded'::character varying, 'converted'::character varying]::text[])", name: "leads_status"
    t.check_constraint "urgency::text = ANY (ARRAY['unknown'::character varying, 'low'::character varying, 'medium'::character varying, 'high'::character varying]::text[])", name: "leads_urgency"
    t.check_constraint "verification_status::text = ANY (ARRAY['unverified'::character varying, 'verified'::character varying, 'unreachable'::character varying, 'rejected'::character varying]::text[])", name: "leads_verification_status"
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
    t.index ["company_id"], name: "index_opportunities_on_company_id"
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
    t.check_constraint "kind::text = ANY (ARRAY['open'::character varying, 'won'::character varying, 'lost'::character varying]::text[])", name: "pipeline_stages_kind"
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
    t.bigint "approved_by_id", null: false
    t.datetime "approved_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_service_rates_on_approved_by_id"
    t.index ["country_id"], name: "index_service_rates_on_country_id"
    t.index ["service_id", "country_id", "valid_from"], name: "idx_on_service_id_country_id_valid_from_46784180d7"
    t.index ["service_id"], name: "index_service_rates_on_service_id"
    t.check_constraint "min_cents >= 0 AND max_cents >= min_cents", name: "service_rates_range"
    t.check_constraint "unit::text = ANY (ARRAY['project'::character varying, 'hour'::character varying, 'month'::character varying]::text[])", name: "service_rates_unit"
    t.check_constraint "valid_until IS NULL OR valid_until >= valid_from", name: "service_rates_validity"
  end

  create_table "services", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_services_on_key", unique: true
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

  add_foreign_key "activities", "users", column: "owner_id"
  add_foreign_key "ai_analyses", "users", column: "reviewed_by_id"
  add_foreign_key "audit_logs", "api_clients"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "companies", "countries"
  add_foreign_key "companies", "users", column: "owner_id"
  add_foreign_key "company_services", "companies", on_delete: :cascade
  add_foreign_key "company_services", "services"
  add_foreign_key "ingestion_requests", "api_clients"
  add_foreign_key "ingestion_requests", "leads", on_delete: :nullify
  add_foreign_key "lead_evidences", "leads", on_delete: :cascade
  add_foreign_key "lead_evidences", "users", column: "captured_by_id"
  add_foreign_key "lead_scores", "leads", on_delete: :cascade
  add_foreign_key "lead_scores", "scoring_criteria"
  add_foreign_key "lead_services", "leads", on_delete: :cascade
  add_foreign_key "lead_services", "services"
  add_foreign_key "leads", "companies"
  add_foreign_key "leads", "countries"
  add_foreign_key "leads", "sources"
  add_foreign_key "leads", "users", column: "owner_id"
  add_foreign_key "opportunities", "companies"
  add_foreign_key "opportunities", "countries"
  add_foreign_key "opportunities", "leads"
  add_foreign_key "opportunities", "pipeline_stages"
  add_foreign_key "opportunities", "users", column: "owner_id"
  add_foreign_key "opportunity_services", "opportunities", on_delete: :cascade
  add_foreign_key "opportunity_services", "services"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "service_rates", "countries"
  add_foreign_key "service_rates", "services"
  add_foreign_key "service_rates", "users", column: "approved_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "roles"
end
