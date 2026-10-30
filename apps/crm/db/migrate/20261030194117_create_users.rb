class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email_address, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.references :role, null: false, foreign_key: true
      t.boolean :active, null: false, default: true
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
