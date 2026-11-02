# Read-only presentation data. Reuses the existing filters and leaves all
# commercial calculations, authorization and state transitions in the backend.
module ArmDashboardHelper
  def arm_dashboard_leads
    @arm_dashboard_leads ||= Lead.filter(@filters).where(detected_at: @metrics.period)
  end

  def arm_dashboard_opportunities
    @arm_dashboard_opportunities ||= begin
      scope = Opportunity.filter(@filters)
      scope = scope.where(lead_id: Lead.where(source_id: @filters[:source_id]).select(:id)) if @filters[:source_id].present?
      scope
    end
  end

  def arm_dashboard_activities
    @arm_dashboard_activities ||= begin
      scope = Activity.pending
      scope = scope.where(owner_id: @filters[:owner_id]) if @filters[:owner_id].present?
      scope
    end
  end

  def arm_capture_series
    zone = Lead.connection.quote(Time.zone.tzinfo.name)
    local_day = Arel.sql("DATE(detected_at AT TIME ZONE 'UTC' AT TIME ZONE #{zone})")
    counts = arm_dashboard_leads.group(local_day).count
    days = (@metrics.to - @metrics.from).to_i + 1
    return [] if days <= 0

    step = [ (days / 60.0).ceil, 1 ].max
    buckets = counts.group_by { |day, _| ((day - @metrics.from).to_i / step) }
    (0...days).step(step).map do |offset|
      [ @metrics.from + offset, Array(buckets[offset / step]).sum { |_, count| count } ]
    end
  end
end
