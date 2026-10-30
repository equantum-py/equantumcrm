# Idempotent reference data. No commercial records, prices or fictitious data.

permissions = {
  "dashboard.read" => "Ver dashboard",
  "leads.read" => "Ver prospectos",
  "leads.write" => "Crear y editar prospectos",
  "companies.read" => "Ver empresas",
  "companies.write" => "Crear y editar empresas",
  "pipeline.read" => "Ver pipeline",
  "pipeline.write" => "Crear y mover oportunidades",
  "pipeline.manage_all" => "Editar oportunidades de otros responsables",
  "activities.write" => "Registrar actividades",
  "ai.review" => "Aceptar o rechazar análisis de IA",
  "rates.read" => "Ver tarifas",
  "rates.manage" => "Aprobar y cargar tarifas",
  "users.manage" => "Administrar usuarios",
  "audit.read" => "Ver registro de auditoría"
}

role_permissions = {
  "admin" => [ "Administrador", permissions.keys ],
  "manager" => [ "Gerente comercial", permissions.keys - %w[users.manage] ],
  "sales" => [ "Ejecutivo comercial", %w[dashboard.read leads.read leads.write companies.read companies.write pipeline.read pipeline.write activities.write ai.review rates.read] ],
  "analyst" => [ "Analista", %w[dashboard.read leads.read leads.write companies.read companies.write pipeline.read activities.write ai.review] ],
  "viewer" => [ "Solo lectura", %w[dashboard.read leads.read companies.read pipeline.read] ]
}

permissions.each do |key, name|
  Permission.find_or_initialize_by(key: key).update!(name: name)
end

role_permissions.each do |key, (name, permission_keys)|
  role = Role.find_or_initialize_by(key: key)
  role.update!(name: name)
  role.permissions = Permission.where(key: permission_keys)
end

[
  [ "PY", "Paraguay", "PYG", "es-PY", "America/Asuncion", true ],
  [ "CL", "Chile", "CLP", "es-CL", "America/Santiago", true ],
  [ "CO", "Colombia", "COP", "es-CO", "America/Bogota", true ],
  [ "ES", "España", "EUR", "es-ES", "Europe/Madrid", true ],
  [ "AR", "Argentina", "ARS", "es-AR", "America/Argentina/Buenos_Aires", false ],
  [ "MX", "México", "MXN", "es-MX", "America/Mexico_City", false ],
  [ "US", "Estados Unidos", "USD", "en-US", "America/New_York", false ]
].each do |iso2, name, currency, locale, timezone, target|
  Country.find_or_initialize_by(iso2: iso2).update!(name: name, default_currency: currency, locale: locale, timezone: timezone, target_market: target)
end

{
  "web_corporativa" => "Página web corporativa", "landing" => "Landing page", "ecommerce" => "Tienda online / ecommerce",
  "shopify" => "Shopify / Shopify Plus", "migracion_ecommerce" => "Migración ecommerce", "app_web" => "Aplicación web / móvil",
  "sistema_empresarial" => "Sistema empresarial", "integraciones" => "Integraciones", "seo" => "SEO",
  "google_ads" => "Google Ads", "meta_ads" => "Meta Ads", "consultoria_comercial" => "Consultoría comercial",
  "consultoria_ecommerce" => "Consultoría ecommerce", "ux_ui" => "UX/UI", "cro" => "Optimización de conversiones (CRO)",
  "analitica_ga4" => "Analítica / GA4", "automatizacion" => "Automatización (n8n)", "ia_negocios" => "IA aplicada a negocios",
  "soporte" => "Mantenimiento y soporte"
}.each do |key, name|
  Service.find_or_initialize_by(key: key).update!(name: name)
end

{
  "facebook" => [ "Facebook", true ], "facebook_group" => [ "Grupo de Facebook", true ], "linkedin" => [ "LinkedIn", true ],
  "workana" => [ "Workana", false ], "upwork" => [ "Upwork", false ], "malt" => [ "Malt", false ],
  "freelance_other" => [ "Otra plataforma freelance", false ], "google_search" => [ "Búsqueda web", false ],
  "google_maps" => [ "Google Maps", false ], "shopify_community" => [ "Comunidad Shopify", false ],
  "public_tender" => [ "Licitación pública", false ], "referral" => [ "Referido", false ],
  "website_form" => [ "Formulario web", false ], "manual" => [ "Carga manual", false ]
}.each do |key, (name, manual)|
  Source.find_or_initialize_by(key: key).update!(name: name, requires_manual_capture: manual)
end

if PipelineStage.none?
  [
    [ "Detectado", "open", 5 ], [ "En investigación", "open", 10 ], [ "Calificado", "open", 20 ],
    [ "Pendiente de contacto", "open", 25 ], [ "Contactado", "open", 30 ], [ "Reunión programada", "open", 45 ],
    [ "Propuesta enviada", "open", 60 ], [ "Negociación", "open", 75 ], [ "Ganado", "won", 100 ], [ "Perdido", "lost", 0 ]
  ].each.with_index(1) do |(name, kind, probability), position|
    PipelineStage.create!(name: name, kind: kind, probability: probability, position: position)
  end
end

[
  [ "explicit_intent", "Intención explícita de contratación", 25 ],
  [ "service_fit", "Compatibilidad con servicios eQuantum", 20 ],
  [ "urgency", "Urgencia", 15 ],
  [ "recency", "Antigüedad de la publicación", 15 ],
  [ "clarity", "Claridad del proyecto", 10 ],
  [ "budget", "Presupuesto declarado y compatible", 5 ],
  [ "target_market", "Mercado objetivo", 5 ],
  [ "contact_possible", "Posibilidad legítima de contacto", 5 ]
].each.with_index(1) do |(key, name, max), position|
  ScoringCriterion.find_or_initialize_by(version: 1, key: key).update!(name: name, max_points: max, position: position)
end

# The first administrator comes from the environment; no default password exists.
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  User.find_or_create_by!(email_address: ENV["ADMIN_EMAIL"]) do |user|
    user.name = ENV.fetch("ADMIN_NAME", "Administrador")
    user.password = ENV["ADMIN_PASSWORD"]
    user.role = Role.find_by!(key: "admin")
  end
end
