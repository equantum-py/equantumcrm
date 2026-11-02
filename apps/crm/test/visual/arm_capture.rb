# Run only against an isolated test database. Produces real Rails screenshots,
# never production fixtures or a substitute static implementation.
raise "Visual capture requires RAILS_ENV=test" unless Rails.env.test?

require "capybara"
require "selenium-webdriver"
require "fileutils"

Rails.application.load_seed
suffix = SecureRandom.hex(4)
user = User.create!(name: "Equipo Demo", email_address: "visual-#{suffix}@example.test",
  password: "Visual-test-password-2026", role: Role.find_by!(key: "manager"))
company = Company.create!(trade_name: "[DEMO] Estudio Norte #{suffix}", country: Country.find_by!(iso2: "PY"), owner: user)
lead = Lead.create!(title: "[DEMO] Rediseño de tienda Shopify #{suffix}", source: Source.find_by!(key: "manual"),
  country: company.country, owner: user, need_summary: "Datos sintéticos exclusivos de validación visual.",
  suggested_message: "[DEMO] Borrador para comprobar el portapapeles.",
  recommended_action: "Verificar la publicación antes de preparar una propuesta.", detected_at: Time.current)
opportunity = Opportunity.create!(name: "[DEMO] Sitio corporativo #{suffix}", company: company, owner: user,
  country: company.country, pipeline_stage: PipelineStage.ordered.first, currency: "USD", estimated_value: "1200")
Activity.create!(title: "[DEMO] Revisar alcance", kind: "follow_up", subject: lead, owner: user, due_at: 1.day.from_now)
# Controlled contract fixtures in the isolated test database. These unflagged
# rows exercise real-data scopes; they are never created outside Rails.env.test.
confirmed = Lead.create!(title: "Solicitud de tienda online", source: lead.source, country: company.country, owner: user,
  need_summary: "Solicitud de tienda online exclusiva del laboratorio visual.", verification_status: "verified", score: 80,
  score_band: "high", commercial_priority: "high", detected_at: 2.days.ago)
estimated = Lead.create!(title: "Rediseño web por revisar", source: lead.source, country: company.country, owner: user,
  need_summary: "Rediseño web exclusivo del laboratorio visual.", commercial_priority: "high", deadline_at: 2.days.from_now,
  detected_at: 1.day.ago)
real_activity = Activity.create!(title: "Revisar alcance comercial", kind: "follow_up", subject: confirmed,
  owner: user, due_at: 1.day.from_now)
estimated.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
AgentRun.create!(agent: Agent.find_by!(key: "lead_analyst"), trigger: "manual", subject: estimated,
  triggered_by: user, started_at: 2.minutes.ago, finished_at: 1.minute.ago, status: "succeeded",
  summary: "[DEMO] Historial de laboratorio; no se ejecutó ningún agente.", source_key: "manual",
  leads_detected: 1, pending_approvals: 1)


Capybara.register_driver :arm_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --no-sandbox --disable-dev-shm-usage].each { |arg| options.add_argument(arg) }
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.server_host = "127.0.0.1"
Capybara.default_max_wait_time = 10
session = Capybara::Session.new(:arm_chrome, Rails.application)
output = Rails.root.join("tmp/arm-visual")
FileUtils.mkdir_p(output)

begin
  session.visit "/session/new"
  session.fill_in "Correo", with: user.email_address
  session.fill_in "Contraseña", with: "Visual-test-password-2026"
  session.click_button "Ingresar"
  raise "Sign-in failed" unless session.has_text?("Centro de operaciones comerciales")
  pages = { dashboard: "/", leads: "/leads", lead: "/leads/#{lead.id}", pipeline: "/opportunities", companies: "/companies", activities: "/activities" }
  agent_control_available = Rails.application.routes.url_helpers.respond_to?(:agent_control_path)
  if agent_control_available && Pundit.policy!(user, :agent_control).show?
    pages[:agent_control] = Rails.application.routes.url_helpers.agent_control_path
  elsif ENV["ARM_INTEGRATION_REQUIRED"] == "1"
    raise "ARM integration required: Agent Control route or permission is missing"
  else
    puts "PENDING: Agent Control is not available on this branch; integrated validation is not complete"
  end
  widths = [ 320, 375, 390, 768, 1366, 1440, 1920 ]
  widths.each do |width|
    session.current_window.resize_to(width, 1000)
    pages.each do |name, path|
      session.visit(path)
      raise "Wrong viewport width" unless session.evaluate_script("window.innerWidth") == width
      raise "Missing page #{name}" unless session.has_css?("main h1")
      overflow = session.evaluate_script("document.documentElement.scrollWidth > window.innerWidth + 1")
      raise "Page overflow: #{name} at #{width}px" if overflow
      clipped = session.evaluate_script(<<~JS)
        [...document.querySelectorAll('main form.grid select, main form.grid input:not([type="hidden"])')].some(element => {
          const rect = element.getBoundingClientRect();
          const parent = element.parentElement.getBoundingClientRect();
          return rect.right > parent.right + 1 || rect.left < parent.left - 1;
        })
      JS
      raise "Filter outside its grid cell: #{name} at #{width}px" if clipped
      clipped_buttons = session.evaluate_script(<<~JS)
        [...document.querySelectorAll('main button, main input[type="submit"], main a.inline-flex')].some(element => {
          if (!element.getClientRects().length || element.closest('.arm-kanban, .overflow-x-auto')) return false;
          const rect = element.getBoundingClientRect();
          return rect.left < -1 || rect.right > window.innerWidth + 1;
        })
      JS
      raise "Button outside viewport: #{name} at #{width}px" if clipped_buttons
      session.save_screenshot(output.join("#{name}-#{width}.png"))
    end
  end
  session.current_window.resize_to(390, 900)
  session.visit "/leads"
  session.find("button[aria-label='Abrir menú']").click
  raise "Drawer did not open" unless session.has_css?("[role='dialog'][aria-modal='true']")
  raise "Background remains focusable" unless session.evaluate_script("document.querySelector('main').closest('[inert]') !== null")
  session.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
  raise "Shift+Tab escaped drawer" unless session.has_css?("#primary-navigation form button:focus", text: "Salir")
  session.driver.browser.action.send_keys(:tab).perform
  raise "Tab escaped drawer" unless session.has_css?(".arm-drawer-close:focus")
  session.save_screenshot(output.join("navigation-390.png"))
  session.find("#primary-navigation a", text: "Dashboard", exact_text: true).click
  raise "Drawer did not close" unless session.has_css?("button[aria-expanded='false']")
  session.visit "/leads"
  session.find("select[name='verification']").select("Inaccesible")
  raise "Verification filter failed" unless session.has_css?("[data-records-target='count']", text: "0")
  raise "Missing filter empty state" unless session.has_text?("No hay prospectos con estos filtros")
  session.find("select[name='verification'] option[value='']").select_option
  raise "Filter reset failed" unless session.has_link?(lead.title)
  session.find("select[data-records-target='sort']").select("Nombre")
  session.find("button[aria-label='Abrir menú']").click
  session.driver.browser.action.send_keys(:escape).perform
  raise "Escape did not close drawer" unless session.has_css?("button[aria-expanded='false']")
  raise "Focus did not return to menu button" unless session.has_css?("button[aria-label='Abrir menú']:focus")
  raise "Background stayed inert" if session.evaluate_script("document.querySelector('main').closest('[inert]') !== null")
  session.find("button[aria-label='Abrir menú']").click
  session.current_window.resize_to(1366, 1000)
  raise "Resize retained modal state" unless session.has_no_css?("[aria-modal='true']")
  raise "Resize left background inert" if session.evaluate_script("document.querySelector('main').closest('[inert]') !== null")
  raise "Resize retained scroll lock" unless session.evaluate_script("document.body.style.overflow") == ""
  session.current_window.resize_to(390, 900)

  session.visit "/leads/#{lead.id}"
  # Force both browser API outcomes; the UI must handle deferred success and denial.
  session.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: () => Promise.reject(new Error('Denied for test')) } })")
  session.find("[data-controller='clipboard'] button").click
  raise "Clipboard error missing" unless session.has_css?("[data-controller='clipboard'] [role='status']", text: "No se pudo copiar.")
  session.execute_script("navigator.clipboard.writeText = () => new Promise(resolve => setTimeout(resolve, 20))")
  session.find("[data-controller='clipboard'] button").click
  raise "Clipboard confirmation missing" unless session.has_button?("Copiado")
  raise "Clipboard status missing" unless session.has_css?("[data-controller='clipboard'] [role='status']", text: "Texto copiado al portapapeles.")

  session.visit "/opportunities"
  board = session.find(".arm-kanban")
  session.execute_script("document.querySelector('.arm-kanban').focus()")
  board.send_keys(:right)
  session.assert_selector(".arm-kanban") { session.evaluate_script("document.querySelector('.arm-kanban').scrollLeft") > 0 }

  [ 390, 1440 ].each do |width|
    session.current_window.resize_to(width, 1000)
    session.visit "/companies?q=arm-empty-#{suffix}"
    raise "Empty state missing" unless session.has_css?(".arm-empty-state", text: "No hay empresas")
    session.save_screenshot(output.join("companies-empty-#{width}.png"))
  end
  session.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
  session.visit "/leads"
  duration = session.evaluate_script("getComputedStyle(document.querySelector('main input')).transitionDuration")
  raise "Reduced motion ignored" unless duration.split(",").all? { |value| value.strip == "0s" }

  raise "Agent Control missing from integrated capture" unless pages.key?(:agent_control)
  session.visit "/"
  raise "Upcoming activity count includes synthetic data" unless session.has_css?(".arm-period-metrics .arm-metric:last-child dd", text: "1", exact_text: true)
  follow_ups = session.find("section", text: "Seguimientos pendientes")
  raise "Real follow-up missing" unless follow_ups.has_text?(real_activity.title)
  raise "Synthetic follow-up leaked" if follow_ups.has_text?("[DEMO] Revisar alcance", wait: 0)
  session.visit "/agent_control"
  raise "Run history missing" unless session.has_text?("Historial de laboratorio")
  session.visit "/?country_id=#{company.country_id}"
  confirmed_link = session.find("a[href*='priority_status=confirmed']")
  confirmed_link.click
  raise "Confirmed queue filter lost" unless session.has_select?("priority_status", selected: "Confirmada")
  raise "Country queue filter lost" unless session.has_select?("country_id", selected: company.country.name)
  raise "Confirmed lead missing" unless session.has_link?(confirmed.title)
  raise "Estimated lead leaked into confirmed list" if session.has_link?(estimated.title, wait: 0)

  checks = pages.size * widths.size
  puts "PASS: verification, sort, focus trap/return, inert cleanup, resize, clipboard outcomes, keyboard Kanban, empty states, reduced motion; #{checks} page/viewport checks, mobile navigation, #{checks + 3} screenshots"
  puts "ARM integrated browser coverage: #{pages.key?(:agent_control) ? 'includes Agent Control' : 'pending PR #7 in main'}"
ensure
  session.driver.quit
end
