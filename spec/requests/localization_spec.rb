# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'Application languages' do
  it 'defaults to English regardless of browser preference' do
    get '/', headers: { 'Accept-Language' => 'de-DE,de;q=0.9' }
    expect(response.headers['Content-Language']).to eq('en')
    expect(response.body).to include('<html lang="en">', 'Find a station')
  end

  { es: 'Buscar una estación', fr: 'Rechercher une station',
    de: 'Station suchen' }.each do |locale, label|
    it "renders #{locale} and remembers an explicit language for subsequent requests" do
      get '/', params: { locale: }
      expect(response.headers['Content-Language']).to eq(locale.to_s)
      expect(response.body).to include("<html lang=\"#{locale}\">", label)
      get '/'
      expect(response.headers['Content-Language']).to eq(locale.to_s)
      expect(I18n.locale).to eq(:en)
    end
  end

  it 'allowlists locales, escapes dictionary JSON and falls back safely' do
    get '/', params: { locale: '</script><script>alert(1)</script>' }
    expect(response.headers['Content-Language']).to eq('en')
    expect(response.body).not_to include('<script>alert(1)</script>')
    expect(response.body).to include('id="app-i18n" type="application/json"')
  end

  it 'translates public API validation errors without changing station identifiers' do
    get '/stations/9999999/report', params: { locale: 'es' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('Esta estación no está en el catálogo actual.')
  end

  it 'keeps complete dictionaries and every interpolation slot in all four languages' do
    english = I18n.t('messages', locale: :en)
    %i[es fr de].each do |locale|
      translated = I18n.t('messages', locale:)
      expect(translated.keys.sort).to eq(english.keys.sort)
      expect(translated.values).to all(be_a(String).and(be_present))
      english.each do |key, phrase|
        expect(translated.fetch(key).scan(/\{\d+\}/).sort).to eq(phrase.scan(/\{\d+\}/).sort)
      end
    end
  end
end
