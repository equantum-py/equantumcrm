namespace :api_clients do
  desc "Create an API client and print its token once. NAME=prospect-ai [SCOPES=leads:ingest]"
  task create: :environment do
    name = ENV.fetch("NAME") { abort "Falta NAME, por ejemplo NAME=prospect-ai" }
    scopes = ENV.fetch("SCOPES", ApiClient::SCOPES.join(",")).split(",").map(&:strip)
    client, token = ApiClient.issue!(name: name, scopes: scopes)
    puts "Cliente ##{client.id} #{client.name} (#{client.scopes.join(', ')})"
    puts "Token (se muestra una sola vez, guardalo como secreto): #{token}"
  end

  desc "Deactivate an API client. NAME=prospect-ai"
  task revoke: :environment do
    client = ApiClient.find_by!(name: ENV.fetch("NAME"))
    client.update!(active: false)
    puts "Cliente #{client.name} desactivado"
  end
end
