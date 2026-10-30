class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :trade_name, null: false
      t.string :legal_name
      t.string :sector
      t.references :country, foreign_key: true
      t.string :website
      t.string :normalized_domain
      t.references :owner, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end
    add_index :companies, :normalized_domain, unique: true, where: "normalized_domain IS NOT NULL"
    add_index :companies, :trade_name

    create_table :company_services do |t|
      t.references :company, null: false, foreign_key: { on_delete: :cascade }
      t.references :service, null: false, foreign_key: true
      t.timestamps
    end
    add_index :company_services, [ :company_id, :service_id ], unique: true
  end
end
