# Rubric v2 ships as a draft: nothing changes for existing leads until
# Dirección activates it (bin/rails rubric:activate VERSION=2).
class AddRubricV2AndCommercialPriority < ActiveRecord::Migration[8.1]
  def change
    create_table :rubric_versions do |t|
      t.integer :version, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :activated_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end
    add_index :rubric_versions, :version, unique: true
    add_index :rubric_versions, :status, unique: true, where: "status = 'active'", name: "index_rubric_versions_single_active"
    add_check_constraint :rubric_versions, "status IN ('draft','active','retired')", name: "rubric_versions_status"

    change_table :services, bulk: true do |t|
      t.string :value_tier, null: false, default: "medium"
      t.boolean :recurring, null: false, default: false
    end
    add_check_constraint :services, "value_tier IN ('high','medium','low')", name: "services_value_tier"

    # Classification only: they sort opportunities by size, they are not prices.
    create_table :commercial_thresholds do |t|
      t.string :currency, null: false, limit: 3
      t.bigint :medium_from_cents, null: false
      t.bigint :high_from_cents, null: false
      t.references :approved_by, foreign_key: { to_table: :users }
      t.string :approval_reference, null: false
      t.datetime :approved_at, null: false
      t.text :notes
      t.timestamps
    end
    add_index :commercial_thresholds, :currency, unique: true
    add_check_constraint :commercial_thresholds, "medium_from_cents >= 0 AND high_from_cents >= medium_from_cents",
                         name: "commercial_thresholds_range"

    # A rate is only used once approved; new and edited rates wait for approval.
    add_column :service_rates, :status, :string, null: false, default: "pending"
    add_reference :service_rates, :created_by, foreign_key: { to_table: :users }
    change_column_null :service_rates, :approved_by_id, true
    change_column_null :service_rates, :approved_at, true
    reversible do |dir|
      dir.up { execute "UPDATE service_rates SET status = 'approved' WHERE approved_by_id IS NOT NULL" }
    end
    add_check_constraint :service_rates, "status IN ('pending','approved','retired')", name: "service_rates_status"
    add_check_constraint :service_rates, "status <> 'approved' OR (approved_by_id IS NOT NULL AND approved_at IS NOT NULL)",
                         name: "service_rates_approval"

    change_table :leads, bulk: true do |t|
      t.string :budget_currency, limit: 3
      t.bigint :budget_min_cents
      t.bigint :budget_max_cents
      t.integer :competition_count
      t.datetime :deadline_at
      t.boolean :listing_closed, null: false, default: false
      t.integer :estimated_hours
      t.string :commercial_priority
      t.integer :priority_score
      t.decimal :priority_confidence, precision: 3, scale: 2
      t.jsonb :priority_breakdown, null: false, default: {}
      t.datetime :priority_calculated_at
    end
    add_index :leads, :commercial_priority
    add_check_constraint :leads, "commercial_priority IN ('high','medium','low','not_recommended')", name: "leads_commercial_priority"
    add_check_constraint :leads, "budget_min_cents IS NULL OR budget_max_cents IS NULL OR budget_max_cents >= budget_min_cents",
                         name: "leads_budget_range"
    add_check_constraint :leads, "competition_count IS NULL OR competition_count >= 0", name: "leads_competition_count"
    add_check_constraint :leads, "estimated_hours IS NULL OR estimated_hours > 0", name: "leads_estimated_hours"
  end
end
