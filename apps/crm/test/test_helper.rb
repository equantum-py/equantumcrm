ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Reference data (roles, permissions, catalogs, stages, rubric) comes from
    # db/seeds.rb, which contains no commercial or personal data.
    parallelize_setup { |_worker| Rails.application.load_seed }

    PASSWORD = "contraseña-de-prueba-segura"

    def create_user(role: "sales", name: nil, email: nil)
      @user_sequence = (@user_sequence || 0) + 1
      User.create!(name: name || "Usuario #{role} #{@user_sequence}", email_address: email || "#{role}#{@user_sequence}-#{SecureRandom.hex(3)}@test.equantum.local",
                   password: PASSWORD, role: Role.find_by!(key: role))
    end

    def create_lead(**attrs)
      Lead.create!({ title: "Solicitud de prueba", source: Source.find_by!(key: "manual"), need_summary: "Texto sintético #{SecureRandom.hex(4)}" }.merge(attrs))
    end

    def score_all!(lead, points: :max, basis: "verified")
      ScoringCriterion.current.each do |criterion|
        value = points == :max ? criterion.max_points : points
        lead.lead_scores.create!(scoring_criterion: criterion, points: value, basis: basis, justification: "prueba")
      end
      lead.recalculate_score!
    end

    def create_company(**attrs)
      Company.create!({ trade_name: "Empresa de prueba #{SecureRandom.hex(3)}" }.merge(attrs))
    end

    def create_opportunity(owner:, stage: PipelineStage.ordered.first, **attrs)
      Opportunity.create!({ name: "Oportunidad de prueba", company: create_company, owner: owner, pipeline_stage: stage }.merge(attrs))
    end
  end
end

Rails.application.load_seed

class ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: ActiveSupport::TestCase::PASSWORD }
  end
end
