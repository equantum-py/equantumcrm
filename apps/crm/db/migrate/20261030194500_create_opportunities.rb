class CreateOpportunities < ActiveRecord::Migration[8.1]
  def change
    create_table :opportunities do |t|
      t.string :name, null: false
      t.references :company, null: false, foreign_key: true
      t.references :lead, foreign_key: true, index: { unique: true }
      t.references :pipeline_stage, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :country, foreign_key: true
      t.bigint :estimated_value_cents
      t.string :currency, limit: 3
      t.date :expected_close_on
      t.datetime :stage_changed_at, null: false
      t.datetime :won_at
      t.datetime :lost_at
      t.string :lost_reason
      t.timestamps
    end
    add_check_constraint :opportunities, "estimated_value_cents IS NULL OR estimated_value_cents >= 0", name: "opportunities_value"
    add_check_constraint :opportunities, "estimated_value_cents IS NULL OR currency IS NOT NULL", name: "opportunities_currency"

    create_table :opportunity_services do |t|
      t.references :opportunity, null: false, foreign_key: { on_delete: :cascade }
      t.references :service, null: false, foreign_key: true
      t.timestamps
    end
    add_index :opportunity_services, [ :opportunity_id, :service_id ], unique: true

    create_table :activities do |t|
      t.string :kind, null: false
      t.references :subject, polymorphic: true, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body
      t.datetime :due_at
      t.datetime :completed_at
      t.string :outcome
      t.timestamps
    end
    add_index :activities, [ :owner_id, :completed_at, :due_at ]
    add_check_constraint :activities, "kind IN ('call','meeting','task','follow_up','reminder','note')", name: "activities_kind"
  end
end
