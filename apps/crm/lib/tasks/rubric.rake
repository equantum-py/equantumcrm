namespace :rubric do
  desc "Simulate moving every lead to another rubric without writing. FROM=1 TO=2"
  task preview: :environment do
    from = Integer(ENV.fetch("FROM", "1"))
    to = Integer(ENV.fetch("TO", "2"))
    rows = RubricMigration.new(from: from, to: to).preview
    puts "Simulación v#{from} → v#{to} (no se escribió nada). Prospectos: #{rows.size}"
    puts format("%-6s %-50s %8s %8s  %-26s %5s %5s", "ID", "Título", "v#{from}", "v#{to}", "Prioridad", "Pts", "Conf")
    rows.each do |row|
      puts format("%-6d %-50s %8s %8s  %-26s %5d %5.2f", row.lead.id, row.lead.title.truncate(50), row.old_score || "-",
                  row.new_score || "-", row.priority.label, row.priority.score, row.priority.confidence)
    end
    puts
    rows.group_by { |row| row.priority.label }.each { |label, group| puts "#{label}: #{group.size}" }
    puts "Con puntuación completa en v#{to}: #{rows.count(&:new_score)} de #{rows.size}"
  end

  desc "Activate a rubric after Dirección approves it. TO=2 APPROVED_BY=email CONFIRM=si"
  task activate: :environment do
    abort "Requiere CONFIRM=si (cambia la puntuación de los prospectos existentes)" unless ENV["CONFIRM"] == "si"

    approver = User.find_by!(email_address: ENV.fetch("APPROVED_BY"))
    from = RubricVersion.active_version
    RubricMigration.new(from: from, to: Integer(ENV.fetch("TO"))).activate!(approved_by: approver)
    puts "Rúbrica v#{ENV['TO']} activa. Aprobó: #{approver.email_address}"
  end
end
