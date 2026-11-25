# frozen_string_literal: true

module ApplicationHelper
  # Source phrases are literal dictionary keys; do not interpret dots as nested I18n paths.
  def ui(message)
    (@ui_messages ||= I18n.t('messages', default: {}))[message.to_sym] || message
  end
end
