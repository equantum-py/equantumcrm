# Moves leads from one rubric to another. Criteria that exist in both are
# rescaled to the new maximum; criteria the target lacks are dropped (in v2,
# urgency and budget move to the commercial priority). preview writes
# nothing; activate! needs a named approver and runs in one transaction.
class RubricMigration
  Row = Data.define(:lead, :old_score, :new_score, :new_band, :priority)

  def initialize(from:, to:)
    @from = from
    @to = to
    @target = ScoringCriterion.where(version: to).ordered.to_a
    raise ArgumentError, "La versión #{to} no tiene criterios" if @target.empty?
  end

  def preview(on: Time.current)
    Lead.includes(:services, :country, lead_scores: :scoring_criterion).find_each.map do |lead|
      mapped = mapped_scores(lead)
      new_score = mapped.size == @target.size ? mapped.sum { |m| m[:points] } : nil
      Row.new(lead: lead, old_score: lead.score, new_score: new_score,
              new_band: new_score && ScoringCriterion.band_for(new_score),
              priority: CommercialPriority.new(lead, on: on).call)
    end
  end

  def activate!(approved_by:)
    raise ArgumentError, "Falta quién aprueba" unless approved_by

    Lead.transaction do
      RubricVersion.find_by!(status: "active").tap { |current| current.update!(status: "retired") }
      RubricVersion.find_by!(version: @to).update!(status: "active", activated_at: Time.current, approved_by: approved_by)
      Lead.find_each do |lead|
        mapped_scores(lead).each do |m|
          lead.lead_scores.find_or_initialize_by(scoring_criterion: m[:criterion])
              .update!(points: m[:points], basis: m[:basis], justification: m[:justification], set_by: m[:set_by])
        end
        lead.recalculate_score!
      end
      AuditLog.record!(action: "rubric_activated", changeset: { "from" => @from, "to" => @to, "approved_by_id" => approved_by.id })
    end
  end

  private
    def mapped_scores(lead)
      previous = lead.lead_scores.select { |score| score.scoring_criterion.version == @from }.index_by { |s| s.scoring_criterion.key }
      @target.filter_map do |criterion|
        old = previous[criterion.key] or next
        points = (old.points * criterion.max_points.to_f / old.scoring_criterion.max_points).round
        { criterion: criterion, points: points, basis: old.basis, set_by: old.set_by,
          justification: [ old.justification, "(reescalado de v#{@from})" ].compact_blank.join(" ") }
      end
    end
end
