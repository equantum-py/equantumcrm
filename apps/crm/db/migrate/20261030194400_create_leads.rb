class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.references :source, null: false, foreign_key: true
      t.references :country, foreign_key: true
      t.references :company, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :need_summary
      t.string :original_url
      t.string :author_display_name
      t.datetime :published_at
      t.datetime :detected_at, null: false
      t.string :published_budget_text
      t.string :urgency, null: false, default: "unknown"
      t.string :verification_status, null: false, default: "unverified"
      t.string :status, null: false, default: "new"
      t.string :discard_reason
      t.integer :score
      t.string :score_band
      t.integer :scoring_version
      t.string :fingerprint, null: false
      t.string :created_via, null: false, default: "manual"
      t.text :suggested_message
      t.text :recommended_action
      t.timestamps
    end
    add_index :leads, :fingerprint, unique: true
    add_index :leads, [ :status, :score ]
    add_index :leads, [ :country_id, :detected_at ]
    add_index :leads, [ :source_id, :detected_at ]
    add_check_constraint :leads, "urgency IN ('unknown','low','medium','high')", name: "leads_urgency"
    add_check_constraint :leads, "verification_status IN ('unverified','verified','unreachable','rejected')", name: "leads_verification_status"
    add_check_constraint :leads, "status IN ('new','researching','qualified','discarded','converted')", name: "leads_status"
    add_check_constraint :leads, "score IS NULL OR score BETWEEN 0 AND 100", name: "leads_score"
    add_check_constraint :leads, "created_via IN ('manual','api','skill')", name: "leads_created_via"

    create_table :lead_services do |t|
      t.references :lead, null: false, foreign_key: { on_delete: :cascade }
      t.references :service, null: false, foreign_key: true
      t.timestamps
    end
    add_index :lead_services, [ :lead_id, :service_id ], unique: true

    create_table :lead_evidences do |t|
      t.references :lead, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false, default: "post_excerpt"
      t.string :url
      t.text :excerpt
      t.datetime :captured_at, null: false
      t.references :captured_by, foreign_key: { to_table: :users }
      t.string :content_sha256
      t.timestamps
    end
    add_check_constraint :lead_evidences, "char_length(excerpt) <= 2000", name: "lead_evidences_excerpt_length"

    create_table :lead_scores do |t|
      t.references :lead, null: false, foreign_key: { on_delete: :cascade }
      t.references :scoring_criterion, null: false, foreign_key: true
      t.integer :points, null: false
      t.string :basis, null: false
      t.text :justification
      t.string :set_by, null: false, default: "human"
      t.timestamps
    end
    add_index :lead_scores, [ :lead_id, :scoring_criterion_id ], unique: true
    add_check_constraint :lead_scores, "points >= 0", name: "lead_scores_points"
    add_check_constraint :lead_scores, "basis IN ('verified','inferred')", name: "lead_scores_basis"

    create_table :ai_analyses do |t|
      t.references :subject, polymorphic: true, null: false
      t.string :kind, null: false
      t.string :provider, null: false
      t.string :engine_version
      t.jsonb :output, null: false, default: {}
      t.string :status, null: false, default: "pending_review"
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end
    add_check_constraint :ai_analyses, "status IN ('pending_review','accepted','rejected','superseded')", name: "ai_analyses_status"
  end
end
