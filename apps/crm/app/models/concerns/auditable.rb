# Writes an audit_logs row for every create, update and destroy.
module Auditable
  extend ActiveSupport::Concern

  FILTERED_ATTRIBUTES = %w[password_digest updated_at created_at].freeze
  ENCRYPTED_PLACEHOLDER = "[cifrado]"

  included do
    after_create_commit { write_audit_log("create", previous_changes) }
    after_update_commit { write_audit_log("update", previous_changes) }
    after_destroy_commit { write_audit_log("destroy", attributes) }
  end

  private
    def write_audit_log(action, changes)
      changeset = mask_encrypted(changes.except(*FILTERED_ATTRIBUTES))
      return if action == "update" && changeset.empty?

      AuditLog.record!(action: action, auditable: self, changeset: changeset)
    end

    # Encrypted attributes hold personal data: the audit log records that they
    # changed, never their value.
    def mask_encrypted(changeset)
      encrypted = Array(self.class.encrypted_attributes).map(&:to_s)
      return changeset if encrypted.empty?

      changeset.to_h { |key, value| encrypted.include?(key.to_s) ? [ key, ENCRYPTED_PLACEHOLDER ] : [ key, value ] }
    end
end
