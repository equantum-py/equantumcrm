# Agent Control: catalog of authorized agents and a record of every run.
# Agents can research, analyze and draft. They never send, contact, price,
# hire or spend: those actions are not representable in allowed_actions.
class CreateAgentsAndAgentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :area, null: false
      t.text :description
      t.boolean :enabled, null: false, default: false
      t.string :execution_mode, null: false, default: "manual"
      t.string :schedule
      t.jsonb :allowed_actions, null: false, default: []
      t.string :implemented_by
      t.timestamps
    end
    add_index :agents, :key, unique: true
    add_check_constraint :agents, "area IN ('prospect_ai','sales_intelligence','sales_agent','relationship_hub')", name: "agents_area"
    add_check_constraint :agents, "execution_mode IN ('manual','scheduled')", name: "agents_execution_mode"

    create_table :agent_runs do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :status, null: false, default: "running"
      t.string :trigger, null: false, default: "manual"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :source_key
      t.string :source_url
      t.text :summary
      t.integer :leads_detected, null: false, default: 0
      t.integer :duplicates, null: false, default: 0
      t.integer :errors_count, null: false, default: 0
      t.jsonb :error_messages, null: false, default: []
      t.integer :pending_approvals, null: false, default: 0
      t.references :subject, polymorphic: true
      t.references :triggered_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :agent_runs, %i[agent_id started_at]
    add_index :agent_runs, :status
    add_check_constraint :agent_runs, "status IN ('running','succeeded','failed','skipped')", name: "agent_runs_status"
    add_check_constraint :agent_runs, "trigger IN ('manual','scheduled','event','api')", name: "agent_runs_trigger"
  end
end
