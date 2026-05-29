class AcceptLanguage
  def initialize(app)
    @app = app
  end

  def call(env)
    I18n.with_locale(preferred_locale(env["HTTP_ACCEPT_LANGUAGE"])) { @app.call(env) }
  end

  private

  def preferred_locale(header)
    return I18n.default_locale unless header

    supported = I18n.available_locales.map(&:to_s)
    parse_header(header).find { |l| supported.include?(l) } || I18n.default_locale
  end

  def parse_header(header)
    header.split(",")
          .map do |part|
            tag, q = part.split(";q=")
            [ tag.strip.split("-").first.downcase, q&.to_f || 1.0 ]
          end
          .sort_by { |_, q| -q }
          .map(&:first)
  end
end
