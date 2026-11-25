# frozen_string_literal: true

class ApplicationController < ActionController::Base
  around_action :with_app_locale

  private

  def with_app_locale(&)
    supported = %w[en es fr de]
    requested = params[:locale]
    locale = supported.include?(requested) ? requested : cookies[:locale]
    locale = 'en' unless supported.include?(locale)
    @app_locale = locale
    if supported.include?(requested)
      cookies[:locale] = { value: locale, expires: 1.year.from_now, same_site: :lax,
                           httponly: true, secure: request.ssl? }
    end
    response.headers['Content-Language'] = locale
    response.headers['Vary'] = 'Cookie'
    I18n.with_locale(locale, &)
  end
end
