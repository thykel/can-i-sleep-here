class ApplicationController < ActionController::API
  around_action :set_locale

  private

  def set_locale
    locale = params[:locale]&.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)
    I18n.with_locale(locale) { yield }
  end
end
