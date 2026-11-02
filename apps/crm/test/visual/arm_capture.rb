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
  recommended_action: "Verificar la publicación antes de preparar una propuesta.", detected_at: Time.current)
opportunity = Opportunity.create!(name: "[DEMO] Sitio corporativo #{suffix}", company: company, owner: user,
  country: company.country, pipeline_stage: PipelineStage.ordered.first, currency: "USD", estimated_value: "1200")
Activity.create!(title: "[DEMO] Revisar alcance", kind: "follow_up", subject: lead, owner: user, due_at: 1.day.from_now)

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
  [ 320, 375, 390, 768, 1366, 1440, 1920 ].each do |width|
    session.current_window.resize_to(width, 1000)
    pages.each do |name, path|
      session.visit(path)
      raise "Wrong viewport width" unless session.evaluate_script("window.innerWidth") == width
      raise "Missing page #{name}" unless session.has_css?("main h1")
      overflow = session.evaluate_script("document.documentElement.scrollWidth > window.innerWidth + 1")
      raise "Page overflow: #{name} at #{width}px" if overflow
      session.save_screenshot(output.join("#{name}-#{width}.png"))
    end
  end
  session.current_window.resize_to(390, 900)
  session.visit "/leads"
  session.find("button[aria-label='Abrir menú']").click
  raise "Drawer did not open" unless session.has_css?("[role='dialog'][aria-modal='true']")
  session.save_screenshot(output.join("navigation-390.png"))
  session.find("#primary-navigation a", text: "Dashboard", exact_text: true).click
  raise "Drawer did not close" unless session.has_css?("button[aria-expanded='false']")
  session.visit "/leads"
  session.find("select[data-records-target='verification']").select("Verificado")
  raise "Verification filter failed" unless session.has_css?("[data-records-target='count']", text: "0")
  raise "Missing filter empty state" unless session.has_text?("No hay registros cargados con esta verificación.")
  session.find("select[data-records-target='verification']").select("Todas")
  raise "Filter reset failed" unless session.has_link?(lead.title)
  session.find("select[data-records-target='sort']").select("Nombre")
  session.find("button[aria-label='Abrir menú']").click
  session.find("#primary-navigation").send_keys(:escape)
  raise "Escape did not close drawer" unless session.has_css?("button[aria-expanded='false']")
  puts "PASS: verification filter, reset, sort, Escape; 42 page/viewport checks, mobile navigation, 43 screenshots"
ensure
  session.driver.quit
end
