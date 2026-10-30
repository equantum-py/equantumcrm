# Writes an audit_logs row for every create, update and destroy.
module Auditable
  extend ActiveSupport::Concern

  FILTERED_ATTRIBUTES = %w[password_digest updated_at created_at].freeze

  included do
    after_create_commit { write_audit_log("create", previous_changes) }
    after_update_commit { write_audit_log("update", previous_changes) }
    after_destroy_commit { write_audit_log("destroy", attributes) }
  end

  private
    def write_audit_log(action, changes)
      changeset = changes.except(*FILTERED_ATTRIBUTES)
      return if action == "update" && changeset.empty?

      AuditLog.record!(action: action, auditable: self, changeset: changeset)
    end
end
