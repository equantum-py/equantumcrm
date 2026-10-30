module ApplicationHelper
  INPUT_CLASS = "block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-xs focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20".freeze
  LABEL_CLASS = "block text-sm font-medium text-slate-700 mb-1".freeze
  BUTTON_PRIMARY = "inline-flex items-center justify-center gap-1.5 rounded-md bg-indigo-600 px-3.5 py-2 text-sm font-semibold text-white shadow-xs hover:bg-indigo-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 cursor-pointer".freeze
  BUTTON_SECONDARY = "inline-flex items-center justify-center gap-1.5 rounded-md bg-white px-3.5 py-2 text-sm font-semibold text-slate-700 shadow-xs ring-1 ring-slate-300 ring-inset hover:bg-slate-50 cursor-pointer".freeze
  BUTTON_DANGER = "inline-flex items-center justify-center gap-1.5 rounded-md bg-white px-3.5 py-2 text-sm font-semibold text-red-700 shadow-xs ring-1 ring-red-200 ring-inset hover:bg-red-50 cursor-pointer".freeze

  LEAD_STATUS = {
    "new" => [ "Nuevo", "bg-sky-50 text-sky-700 ring-sky-600/20" ],
    "researching" => [ "En investigación", "bg-amber-50 text-amber-800 ring-amber-600/20" ],
    "qualified" => [ "Calificado", "bg-emerald-50 text-emerald-700 ring-emerald-600/20" ],
    "discarded" => [ "Descartado", "bg-slate-100 text-slate-600 ring-slate-500/20" ],
    "converted" => [ "Convertido", "bg-indigo-50 text-indigo-700 ring-indigo-600/20" ]
  }.freeze

  VERIFICATION = {
    "unverified" => [ "Sin verificar", "bg-slate-100 text-slate-600 ring-slate-500/20" ],
    "verified" => [ "Verificado", "bg-emerald-50 text-emerald-700 ring-emerald-600/20" ],
    "unreachable" => [ "Inaccesible", "bg-red-50 text-red-700 ring-red-600/20" ],
    "rejected" => [ "Rechazado", "bg-red-50 text-red-700 ring-red-600/20" ]
  }.freeze

  BANDS = {
    "very_high" => [ "Muy alta", "bg-emerald-600 text-white ring-emerald-700" ],
    "high" => [ "Alta", "bg-emerald-50 text-emerald-800 ring-emerald-600/30" ],
    "medium" => [ "Media", "bg-amber-50 text-amber-800 ring-amber-600/30" ],
    "low" => [ "Baja", "bg-slate-100 text-slate-600 ring-slate-500/20" ]
  }.freeze

  ACTIVITY_KINDS = { "call" => "Llamada", "meeting" => "Reunión", "task" => "Tarea", "follow_up" => "Seguimiento", "reminder" => "Recordatorio", "note" => "Nota interna" }.freeze
  URGENCIES = { "unknown" => "Sin indicio", "low" => "Baja", "medium" => "Media", "high" => "Alta" }.freeze
  RATE_UNITS = { "project" => "Por proyecto", "hour" => "Por hora", "month" => "Mensual" }.freeze
  CURRENCIES = %w[PYG CLP COP EUR USD].freeze

  def badge(label, classes)
    tag.span(label, class: "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap #{classes}")
  end

  def lead_status_badge(status) = badge(*LEAD_STATUS.fetch(status, [ status, "" ]))
  def verification_badge(status) = badge(*VERIFICATION.fetch(status, [ status, "" ]))

  def score_badge(lead)
    return badge("Sin puntuar", "bg-white text-slate-500 ring-slate-300") if lead.score.nil?

    label, classes = BANDS.fetch(lead.score_band)
    badge("#{lead.score} · #{label}", classes)
  end

  def stage_badge(stage)
    classes = case stage.kind
    when "won" then "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    when "lost" then "bg-red-50 text-red-700 ring-red-600/20"
    else "bg-slate-50 text-slate-700 ring-slate-500/20"
    end
    badge(stage.name, classes)
  end

  def nav_link(label, path, icon:, active: nil)
    active = current_page?(path) || request.path.start_with?(path.to_s) && path != root_path if active.nil?
    classes = active ? "bg-indigo-50 text-indigo-700" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
    link_to path, class: "group flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium #{classes}", aria: { current: (active ? "page" : nil) } do
      safe_join([ icon_svg(icon, "size-5 shrink-0 #{active ? 'text-indigo-600' : 'text-slate-400 group-hover:text-slate-600'}"), tag.span(label) ])
    end
  end

  ICONS = {
    home: "M2.25 12l8.954-8.955a1.126 1.126 0 011.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75",
    spark: "M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z",
    users: "M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z",
    funnel: "M3 4.5h18l-7 8.25V19.5l-4 1.5v-8.25L3 4.5z",
    building: "M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21",
    check: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    tag: "M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z",
    shield: "M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z",
    list: "M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z",
    plus: "M12 4.5v15m7.5-7.5h-15",
    search: "M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z",
    menu: "M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5",
    chart: "M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"
  }.freeze

  PRIORITY_STYLES = { "high" => "bg-emerald-50 text-emerald-800 ring-emerald-200", "medium" => "bg-sky-50 text-sky-800 ring-sky-200",
                      "low" => "bg-slate-50 text-slate-700 ring-slate-200", "not_recommended" => "bg-rose-50 text-rose-800 ring-rose-200" }.freeze
  PRIORITY_FACTORS = { "budget_vs_rate" => "Presupuesto vs. tarifa aprobada", "economic_value" => "Valor económico",
                       "service_value" => "Valor del servicio", "profitability" => "Rentabilidad estimada",
                       "competition" => "Competencia", "urgency" => "Urgencia", "recency" => "Antigüedad" }.freeze

  def icon_svg(name, classes = "size-5")
    tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor", class: classes, aria: { hidden: true }) do
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: ICONS.fetch(name))
    end
  end

  def field_error(record, attribute)
    messages = record.errors[attribute]
    tag.p(messages.to_sentence, class: "mt-1 text-xs text-red-600") if messages.any?
  end

  def form_errors(record)
    return if record.errors.empty?

    tag.div(class: "mb-6 rounded-md bg-red-50 p-4 ring-1 ring-red-200", role: "alert") do
      safe_join([ tag.p("Revisá los siguientes datos:", class: "text-sm font-semibold text-red-800"),
                  tag.ul(safe_join(record.errors.full_messages.map { |m| tag.li(m) }), class: "mt-2 list-disc pl-5 text-sm text-red-700") ])
    end
  end

  def date_label(time)
    time ? l(time.to_date, format: :short_es) : "—"
  end

  def datetime_label(time)
    time ? time.in_time_zone.strftime("%d/%m/%Y %H:%M") : "—"
  end

  # Renders an external link only for http(s) URLs, so a stored javascript: URL can never execute.
  def external_link(label, url, **options)
    return label unless UrlCanonicalizer.http_url?(url)

    link_to label, URI.parse(url.strip).to_s, target: "_blank", rel: "noopener noreferrer nofollow", **options
  end

  def options_for_users = User.active.ordered.pluck(:name, :id)
  def options_for_countries = Country.ordered.pluck(:name, :id)
  def options_for_services = Service.active.ordered.pluck(:name, :id)
  def options_for_sources = Source.ordered.pluck(:name, :id)
end
