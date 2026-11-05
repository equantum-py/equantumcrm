# Phase 1 (PR-1) of the multichannel plan (ARM_FASE1_PLAN_TECNICO_V1_FINAL r2,
# section 9): the tables that receive Meta webhooks and hold contacts,
# conversations, form submissions and the attention inbox. Nothing here sends
# messages: messages.direction is constrained to inbound only.
#
# Columns marked "encrypted" are written through Active Record Encryption, so
# they are text and never hold plain personal data.
class CreateMetaInboundFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :external_account_id, null: false
      t.string :status, null: false, default: "planned"
      t.references :default_owner, foreign_key: { to_table: :users }
      t.boolean :auto_confirm, null: false, default: false
      t.boolean :auto_create_lead, null: false, default: false
      t.boolean :synthetic, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.datetime :last_event_at
      t.timestamps
      t.index %i[kind external_account_id], unique: true
      t.check_constraint "kind IN ('whatsapp','meta_lead_ads','instagram')", name: "channels_kind_valid"
      t.check_constraint "status IN ('planned','configured','operational','paused')", name: "channels_status_valid"
    end

    create_table :contacts do |t|
      t.string :name
      t.string :phone_e164 # encrypted (deterministic)
      t.string :email # encrypted (deterministic)
      t.references :company, foreign_key: true
      t.references :primary_contact, foreign_key: { to_table: :contacts }
      t.string :consent_source
      t.datetime :consent_at
      t.boolean :do_not_contact, null: false, default: false
      t.datetime :anonymized_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index :phone_e164
      t.index :email
    end

    create_table :external_identities do |t|
      t.references :channel, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :profile_name
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
      t.index %i[channel_id external_id], unique: true
    end

    create_table :contact_matches do |t|
      t.references :contact, null: false, foreign_key: true
      t.references :candidate_contact, null: false, foreign_key: { to_table: :contacts }
      t.string :reason, null: false
      t.string :status, null: false, default: "pending"
      t.references :decided_by, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.timestamps
      t.index %i[contact_id candidate_contact_id], unique: true
      t.check_constraint "contact_id <> candidate_contact_id", name: "contact_matches_distinct"
      t.check_constraint "reason IN ('same_phone','same_email')", name: "contact_matches_reason_valid"
      t.check_constraint "status IN ('pending','accepted','rejected','reverted')", name: "contact_matches_status_valid"
    end

    create_table :webhook_events do |t|
      t.string :provider, null: false, default: "meta"
      t.string :object_type, null: false
      t.string :event_key, null: false
      t.references :channel, foreign_key: true
      t.text :payload, null: false # encrypted JSON fragment
      t.jsonb :summary, null: false, default: {} # sanitized: kind, ids and times only
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :received_at, null: false
      t.datetime :last_enqueued_at
      t.datetime :processed_at
      t.timestamps
      t.index :event_key, unique: true
      t.index %i[status received_at]
      t.check_constraint "status IN ('pending','processed','failed','ignored')", name: "webhook_events_status_valid"
    end

    create_table :conversations do |t|
      t.references :channel, null: false, foreign_key: true
      # One conversation per external identity, reused when it reopens (P1).
      t.references :external_identity, null: false, foreign_key: true, index: { unique: true }
      t.references :contact, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.datetime :last_inbound_at
      t.datetime :window_expires_at
      t.datetime :reopened_at
      t.timestamps
      t.check_constraint "status IN ('open','closed')", name: "conversations_status_valid"
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true, index: false
      t.string :direction, null: false, default: "in"
      t.string :external_message_id, null: false
      t.string :message_kind, null: false, default: "text"
      t.string :content_status, null: false, default: "ok"
      t.text :body # encrypted
      t.jsonb :media, null: false, default: {}
      t.datetime :sent_at, null: false
      t.datetime :received_at, null: false
      t.references :webhook_event, foreign_key: true
      t.timestamps
      t.index :external_message_id, unique: true
      t.index %i[conversation_id sent_at id]
      # Phase 1 never sends: the database itself rejects outbound rows.
      t.check_constraint "direction = 'in'", name: "messages_inbound_only"
      t.check_constraint "content_status IN ('ok','unsupported','unavailable')", name: "messages_content_status_valid"
    end

    create_table :lead_form_submissions do |t|
      t.references :channel, null: false, foreign_key: true
      t.string :leadgen_id, null: false
      t.string :form_id
      t.string :form_name
      t.string :ad_id
      t.string :ad_name
      t.string :campaign_id
      t.string :campaign_name
      t.string :platform
      t.boolean :is_organic
      t.string :retrieval_status, null: false, default: "pending"
      t.text :retrieval_error
      t.text :field_data # encrypted JSON
      t.datetime :submitted_at
      t.datetime :received_at, null: false
      t.datetime :retrieved_at
      t.references :contact, foreign_key: true
      t.references :lead, foreign_key: true
      t.references :webhook_event, foreign_key: true
      t.timestamps
      t.index :leadgen_id, unique: true
      t.check_constraint "retrieval_status IN ('pending','retrieved','failed')", name: "lead_form_submissions_retrieval_status_valid"
    end

    create_table :inbox_items do |t|
      t.string :kind, null: false
      t.references :subject, polymorphic: true, null: false, index: { unique: true }
      t.references :channel, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :lead, foreign_key: true
      t.string :attention_status, null: false, default: "new"
      t.string :discard_reason
      t.datetime :review_at
      t.string :assignment_status, null: false, default: "unassigned"
      t.references :proposed_owner, foreign_key: { to_table: :users }
      t.references :proposed_by, foreign_key: { to_table: :users }
      t.datetime :proposed_at
      t.string :proposal_source
      t.text :proposal_note
      t.references :confirmed_owner, foreign_key: { to_table: :users }, index: false
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.datetime :first_attended_at
      t.datetime :last_activity_at, null: false
      t.text :preview # encrypted
      t.integer :reopened_count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index %i[last_activity_at id], order: { last_activity_at: :desc, id: :desc }
      t.index %i[updated_at last_activity_at]
      t.index %i[confirmed_owner_id attention_status]
      t.index :assignment_status, where: "assignment_status <> 'confirmed'", name: "index_inbox_items_pending_assignment"
      t.check_constraint "kind IN ('conversation','form_submission')", name: "inbox_items_kind_valid"
      t.check_constraint "attention_status IN ('new','in_progress','waiting_customer','resolved','discarded')", name: "inbox_items_attention_status_valid"
      t.check_constraint "assignment_status IN ('unassigned','proposed','confirmed')", name: "inbox_items_assignment_status_valid"
      t.check_constraint "proposal_source IS NULL OR proposal_source IN ('rule','manager')", name: "inbox_items_proposal_source_valid"
      t.check_constraint "attention_status <> 'discarded' OR discard_reason IS NOT NULL", name: "inbox_items_discard_needs_reason"
      t.check_constraint "attention_status <> 'waiting_customer' OR review_at IS NOT NULL", name: "inbox_items_waiting_needs_review_at"
      t.check_constraint "assignment_status <> 'confirmed' OR confirmed_owner_id IS NOT NULL", name: "inbox_items_confirmed_needs_owner"
      t.check_constraint "assignment_status <> 'proposed' OR proposed_owner_id IS NOT NULL", name: "inbox_items_proposed_needs_owner"
    end

    create_table :inbox_notes do |t|
      t.references :inbox_item, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false # encrypted
      t.timestamps
      t.index %i[inbox_item_id created_at]
    end

    create_table :assignments do |t|
      t.references :inbox_item, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.references :actor, foreign_key: { to_table: :users } # null when a rule proposed it
      t.string :source, null: false
      t.text :reason
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
      t.index %i[inbox_item_id ended_at]
      t.check_constraint "kind IN ('proposed','confirmed')", name: "assignments_kind_valid"
    end

    # Idempotent replays of inbox actions (P3): the same operation_id answers
    # with the stored result instead of applying twice.
    create_table :inbox_operations do |t|
      t.uuid :operation_id, null: false
      t.references :target, polymorphic: true, null: false
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :request_sha256, null: false
      t.integer :response_status, null: false
      t.jsonb :response_body, null: false, default: {}
      t.integer :resulting_lock_version
      t.datetime :created_at, null: false
      t.index :operation_id, unique: true
      t.index :created_at
    end

    add_reference :leads, :contact, foreign_key: true
    add_reference :opportunities, :contact, foreign_key: true
    add_reference :activities, :inbox_item, foreign_key: true
    add_column :activities, :rule_key, :string
    add_index :activities, %i[inbox_item_id rule_key], unique: true, where: "rule_key IS NOT NULL",
              name: "index_activities_on_inbox_item_and_rule_key"
  end
end
