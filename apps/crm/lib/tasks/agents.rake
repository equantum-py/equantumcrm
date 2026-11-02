namespace :agents do
  desc "Ejecuta a mano el colector de Freelancer (agente prospect_scout). DRY_RUN=1 simula sin registrar prospectos. " \
       "BY=correo de quien lo ejecuta. MAX_REQUESTS=10 limita las consultas a la API"
  task collect_freelancer: :environment do
    user = ENV["BY"].presence && User.find_by!(email_address: ENV["BY"])
    collector = Collectors::Freelancer.new(triggered_by: user, dry_run: ENV["DRY_RUN"] == "1",
                                           max_requests: Integer(ENV.fetch("MAX_REQUESTS", Collectors::Freelancer::DEFAULTS[:max_requests])))
    summary = collector.call
    puts summary.run.summary
    summary.errors.each { |message| puts "  Error: #{message}" }
    puts "Ejecución ##{summary.run.id} registrada en Agent Control. Los prospectos quedan sin verificar."
  rescue Agent::NotAuthorized => e
    abort "No autorizado: #{e.message}. Activar el agente es una decisión de Dirección."
  end
end
