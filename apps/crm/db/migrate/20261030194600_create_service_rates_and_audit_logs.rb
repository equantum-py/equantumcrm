class CreateServiceRatesAndAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :service_rates do |t|
      t.references :service, null: false, foreign_key: true
      t.references :country, foreign_key: true
      t.string :currency, null: false, limit: 3
      t.string :unit, null: false
      t.bigint :min_cents, null: false
      t.bigint :max_cents, null: false
      t.date :valid_from, null: false
      t.date :valid_until
      t.references :approved_by, null: false, foreign_key: { to_table: :users }
      t.datetime :approved_at, null: false
      t.text :notes
      t.timestamps
    end
    add_index :service_rates, [ :service_id, :country_id, :valid_from ]
    add_check_constraint :service_rates, "min_cents >= 0 AND max_cents >= min_cents", name: "service_rates_range"
    add_check_constraint :service_rates, "unit IN ('project','hour','month')", name: "service_rates_unit"
    add_check_constraint :service_rates, "valid_until IS NULL OR valid_until >= valid_from", name: "service_rates_validity"

    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.references :auditable, polymorphic: true
      t.jsonb :changeset, null: false, default: {}
      t.string :ip_address
      t.string :request_id
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :created_at
  end
end
