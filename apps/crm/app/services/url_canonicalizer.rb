# Canonical form of a URL for duplicate detection: lowercase host without
# www./m. prefixes, no fragment, no tracking parameters, sorted query.
module UrlCanonicalizer
  TRACKING_PARAMS = /\A(utm_.*|fbclid|gclid|mibextid|rdid|share_url|ref|refid|__cft__.*|__tn__.*|_rdr|sfnsn|igshid|trk|trackingId)\z/
  HOST_PREFIXES = /\A(www|m|mbasic|web|touch)\./

  module_function

  def http_url?(value)
    uri = URI.parse(value.to_s.strip)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def canonical(value)
    return unless http_url?(value)

    uri = URI.parse(value.to_s.strip)
    host = uri.host.downcase.sub(HOST_PREFIXES, "")
    path = uri.path.to_s.sub(%r{/+\z}, "")
    params = URI.decode_www_form(uri.query.to_s).reject { |key, _| key.match?(TRACKING_PARAMS) }.sort
    query = params.any? ? "?#{URI.encode_www_form(params)}" : ""
    "#{host}#{path}#{query}"
  end

  def domain(value)
    return unless http_url?(value)

    URI.parse(value.to_s.strip).host.downcase.sub(HOST_PREFIXES, "")
  end
end
