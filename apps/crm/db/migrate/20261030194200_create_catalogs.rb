class CreateCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :iso2, null: false, limit: 2
      t.string :name, null: false
      t.string :default_currency, null: false, limit: 3
      t.string :locale, null: false
      t.string :timezone, null: false
      t.boolean :target_market, null: false, default: false
      t.timestamps
    end
    add_index :countries, :iso2, unique: true

    create_table :services do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :services, :key, unique: true

    create_table :sources do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :requires_manual_capture, null: false, default: false
      t.timestamps
    end
    add_index :sources, :key, unique: true

    create_table :pipeline_stages do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.string :kind, null: false, default: "open"
      t.integer :probability, null: false, default: 0
      t.timestamps
    end
    add_index :pipeline_stages, :position, unique: true
    add_check_constraint :pipeline_stages, "kind IN ('open','won','lost')", name: "pipeline_stages_kind"
    add_check_constraint :pipeline_stages, "probability BETWEEN 0 AND 100", name: "pipeline_stages_probability"

    create_table :scoring_criteria do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.integer :max_points, null: false
      t.integer :position, null: false
      t.integer :version, null: false, default: 1
      t.text :guidance
      t.timestamps
    end
    add_index :scoring_criteria, [ :version, :key ], unique: true
    add_check_constraint :scoring_criteria, "max_points > 0", name: "scoring_criteria_max_points"
  end
end
