require 'spec_helper'
require 'spree/testing_support/url_helpers'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  def index
    render plain: 'index'
  end
end

describe Spree::Core::ControllerHelpers::Auth, type: :controller do
  controller(FakesController) {}
  include Spree::TestingSupport::UrlHelpers

  describe '#current_ability' do
    it 'returns Spree::Ability instance' do
      expect(controller.current_ability.class).to eq Spree::Ability
    end
  end

  describe '#redirect_back_or_default' do
    controller(FakesController) do
      def index
        redirect_back_or_default('/')
      end
    end

    it 'redirects to session url' do
      session[:spree_user_return_to] = '/redirect'
      get :index
      expect(response).to redirect_to('/redirect')
    end
    it 'redirects to HTTP_REFERER' do
      request.env['HTTP_REFERER'] = '/dummy_redirect'
      get :index
      expect(response).to redirect_to('/dummy_redirect')
    end
    it 'redirects to default page' do
      get :index
      expect(response).to redirect_to('/')
    end
  end

  describe '#set_token' do
    controller(FakesController) do
      def index
        set_token
        render plain: 'index'
      end
    end

    it 'sends cookie header' do
      get :index
      expect(response.cookies['token']).not_to be_nil
    end
    it 'sets httponly flag' do
      get :index
      if Rails::VERSION::STRING >= '7.1.0'
        token_header = response.headers['Set-Cookie'].find { |e| e.starts_with?('token=') }
        expect(token_header).to include('httponly')
      else
        expect(response['Set-Cookie']).to include('HttpOnly')
      end
    end
  end

  describe '#store_location' do
    it 'sets session return url' do
      allow(controller).to receive_messages(request: double(fullpath: '/redirect'))
      controller.store_location
      expect(session[:spree_user_return_to]).to eq '/redirect'
    end
  end

  describe '#try_spree_current_user' do
    it 'calls spree_current_user when define spree_current_user method' do
      expect(controller).to receive(:spree_current_user)
      controller.try_spree_current_user
    end
    it 'calls current_spree_user when define current_spree_user method' do
      expect(controller).to receive(:current_spree_user)
      controller.try_spree_current_user
    end
    it 'returns nil' do
      expect(controller.try_spree_current_user).to eq nil
    end
  end
end
