class CreateApiClientsAndIngestionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :scopes, array: true, null: false, default: []
      t.boolean :active, null: false, default: true
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :api_clients, :token_digest, unique: true
    add_index :api_clients, :name, unique: true

    create_table :ingestion_requests do |t|
      t.references :api_client, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.string :request_sha256, null: false
      t.integer :response_status, null: false
      t.jsonb :response_body, null: false, default: {}
      t.references :lead, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :ingestion_requests, [ :api_client_id, :idempotency_key ], unique: true
    add_check_constraint :ingestion_requests, "char_length(idempotency_key) BETWEEN 8 AND 128", name: "ingestion_requests_key_length"

    change_table :leads, bulk: true do |t|
      t.string :external_id
      t.boolean :published_at_verified, null: false, default: false
      t.string :contact_channel_kind
    end

    add_reference :audit_logs, :api_client, foreign_key: true
  end
end
