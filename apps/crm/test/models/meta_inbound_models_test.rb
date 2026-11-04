require "test_helper"

# PR-1: data model guarantees (plan r2, section 9) enforced by the database or
# by the models, and encryption/audit behaviour (S17, S19).
class MetaInboundModelsTest < ActiveSupport::TestCase
  def channel(kind: "whatsapp")
    Channel.create!(kind: kind, name: "Canal sintético", external_account_id: "E2E-#{SecureRandom.hex(4)}", synthetic: true)
  end

  def contact(**attrs)
    Contact.create!({ name: "Contacto Sintético" }.merge(attrs))
  end

  def conversation(chan = channel)
    person = contact
    identity = ExternalIdentity.create!(channel: chan, contact: person, external_id: "E2E-#{SecureRandom.hex(4)}",
                                        first_seen_at: Time.current, last_seen_at: Time.current)
    Conversation.create!(channel: chan, external_identity: identity, contact: person)
  end

  def inbox_item(**attrs)
    conv = conversation
    InboxItem.create!({ kind: "conversation", subject: conv, channel: conv.channel, contact: conv.contact,
                        last_activity_at: Time.current }.merge(attrs))
  end

  # A rejected statement aborts the surrounding test transaction unless it
  # runs inside its own savepoint.
  def assert_db_rejects(error = ActiveRecord::StatementInvalid, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def raw_column(model, column)
    model.class.connection.select_value("SELECT #{column} FROM #{model.class.table_name} WHERE id = #{model.id}")
  end

  # S19
  test "the database rejects outbound messages" do
    conv = conversation
    message = Message.create!(conversation: conv, external_message_id: "wamid.E2E-#{SecureRandom.hex(4)}", body: "hola",
                              sent_at: Time.current, received_at: Time.current)
    assert_db_rejects(ActiveRecord::StatementInvalid) { message.update_column(:direction, "out") }
    assert_not Message.new(direction: "out").valid?
  end

  test "identities, conversations, messages and submissions are unique by their external ids" do
    conv = conversation
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      ExternalIdentity.new(channel: conv.channel, contact: conv.contact, external_id: conv.external_identity.external_id,
                           first_seen_at: Time.current, last_seen_at: Time.current).save!(validate: false)
    end
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      Conversation.new(channel: conv.channel, external_identity: conv.external_identity, contact: conv.contact).save!(validate: false)
    end
    Message.create!(conversation: conv, external_message_id: "wamid.E2E-same", sent_at: Time.current, received_at: Time.current)
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      Message.new(conversation: conv, external_message_id: "wamid.E2E-same", sent_at: Time.current, received_at: Time.current).save!(validate: false)
    end
    leads = channel(kind: "meta_lead_ads")
    LeadFormSubmission.create!(channel: leads, leadgen_id: "E2E-LEAD-1", received_at: Time.current)
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      LeadFormSubmission.new(channel: leads, leadgen_id: "E2E-LEAD-1", received_at: Time.current).save!(validate: false)
    end
  end

  test "one inbox item per subject and states guarded by the database" do
    item = inbox_item
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      InboxItem.new(kind: "conversation", subject: item.subject, channel: item.channel, last_activity_at: Time.current).save!(validate: false)
    end
    assert_db_rejects(ActiveRecord::StatementInvalid) { item.update_columns(attention_status: "discarded") }
    item.reload
    assert_db_rejects(ActiveRecord::StatementInvalid) { item.update_columns(attention_status: "waiting_customer") }
    item.reload
    assert_db_rejects(ActiveRecord::StatementInvalid) { item.update_columns(assignment_status: "confirmed") }
    item.reload
    assert_db_rejects(ActiveRecord::StatementInvalid) { item.update_columns(kind: "email") }
  end

  test "inbox item validations mirror the constraints" do
    item = inbox_item
    item.attention_status = "discarded"
    assert_not item.valid?
    item.discard_reason = "spam"
    assert item.valid?
    item.attention_status = "waiting_customer"
    assert_not item.valid?
    item.review_at = 1.day.from_now
    assert item.valid?
    item.subject = item.channel.lead_form_submissions.build(leadgen_id: "x", received_at: Time.current)
    assert_not item.valid?
  end

  test "optimistic locking rejects a stale inbox item" do
    item = inbox_item
    stale = InboxItem.find(item.id)
    item.update!(attention_status: "in_progress")
    stale.attention_status = "resolved"
    assert_raises(ActiveRecord::StaleObjectError) { stale.save! }
  end

  test "personal data is encrypted at rest and contacts are still found by phone" do
    person = contact(phone_e164: "+595 981 000-222", email: "Sintetico@E2E.invalid")
    assert_equal "+595981000222", person.phone_e164
    assert_not_includes raw_column(person, "phone_e164"), "595981000222"
    assert_not_includes raw_column(person, "email"), "sintetico"
    assert_equal person, Contact.find_by(phone_e164: "+595981000222")
    assert_equal person, Contact.find_by(email: "sintetico@e2e.invalid")
    assert_equal "+595*******22", person.masked_phone

    note = InboxNote.create!(inbox_item: inbox_item, author: create_user, body: "Nota privada sintética")
    assert_not_includes raw_column(note, "body"), "privada"
  end

  # S17 (model side)
  test "the audit log records that encrypted fields changed, never their value" do
    person = contact(phone_e164: "+595981000333", email: "audit@e2e.invalid")
    log = AuditLog.where(auditable: person, action: "create").last
    assert_equal "[cifrado]", log.changeset["phone_e164"]
    assert_equal "[cifrado]", log.changeset["email"]
    assert_equal [ nil, "Contacto Sintético" ], log.changeset["name"]

    person.update!(phone_e164: "+595981000444")
    update = AuditLog.where(auditable: person, action: "update").last
    assert_equal "[cifrado]", update.changeset["phone_e164"]
    assert_not_includes AuditLog.where(auditable: person).map { |row| row.changeset.to_json }.join, "595981000"
  end

  test "rule activities are unique per inbox item and rule key" do
    item = inbox_item
    lead = create_lead
    owner = create_user
    Activity.create!(kind: "task", subject: lead, owner: owner, title: "Revisar solicitud", inbox_item: item, rule_key: "r1_review")
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      Activity.create!(kind: "task", subject: lead, owner: owner, title: "Revisar solicitud", inbox_item: item, rule_key: "r1_review")
    end
    assert Activity.create!(kind: "note", subject: lead, owner: owner, title: "Manual", inbox_item: item)
  end

  test "contact matches link two different contacts" do
    first = contact
    assert_not ContactMatch.new(contact: first, candidate_contact: first, reason: "same_phone").valid?
    match = ContactMatch.create!(contact: first, candidate_contact: contact, reason: "same_phone")
    assert_equal "pending", match.status
    assert_db_rejects(ActiveRecord::StatementInvalid) { match.update_columns(reason: "same_name") }
  end

  test "inbox operations recognise only identical retries" do
    item = inbox_item
    actor = create_user(role: "manager")
    sha = InboxOperation.fingerprint(:confirm, { "lock_version" => 0, "proposed_owner_id" => 5 })
    op = InboxOperation.create!(operation_id: SecureRandom.uuid, target: item, actor: actor, action: "confirm",
                                request_sha256: sha, response_status: 200, response_body: { "lock_version" => 1 })
    assert op.replay_of?(actor: actor, action: :confirm, request_sha256: sha)
    assert_not op.replay_of?(actor: create_user(role: "manager"), action: :confirm, request_sha256: sha)
    assert_not op.replay_of?(actor: actor, action: :confirm, request_sha256: InboxOperation.fingerprint(:confirm, { "lock_version" => 1 }))
    assert_equal sha, InboxOperation.fingerprint("confirm", { "proposed_owner_id" => 5, "lock_version" => 0 })
    assert_db_rejects(ActiveRecord::RecordNotUnique) do
      InboxOperation.new(op.attributes.except("id")).save!(validate: false)
    end
  end

  test "channels accept only the planned kinds and states" do
    assert_not Channel.new(kind: "telegram", name: "x", external_account_id: "1").valid?
    chan = channel
    assert_equal "planned", chan.status
    assert_db_rejects(ActiveRecord::StatementInvalid) { chan.update_columns(status: "live") }
  end

  test "leads, opportunities and activities can reference a contact or inbox item" do
    person = contact
    lead = create_lead(contact: person)
    assert_equal person, lead.reload.contact
    opportunity = create_opportunity(owner: create_user, contact: person)
    assert_equal person, opportunity.reload.contact
  end
end
