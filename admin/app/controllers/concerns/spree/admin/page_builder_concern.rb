module Spree
  module Admin
    module PageBuilderConcern
      extend ActiveSupport::Concern

      included do
        before_action :set_variables
        layout :choose_layout
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/page_builder'
      end

      def set_variables
        @theme_preview = current_store.theme_previews.find(session[:theme_preview_id]) if session[:theme_preview_id].present?
        @theme = @theme_preview.parent if @theme_preview
        if session[:page_preview_id].present?
          @page_preview = @theme.page_previews.find_by(id: session[:page_preview_id]) ||
                            current_store.page_previews.find(session[:page_preview_id])
        end
        @page = @page_preview.parent if @page_preview
      end

      def create_turbo_stream_enabled?
        true
      end

      def update_turbo_stream_enabled?
        true
      end

      def default_url_options
        {
          theme_preview_id: session[:theme_preview_id],
          page_preview_id: session[:page_preview_id],
        }
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.edit_admin_theme_path(@theme, page_id: @page.id)
      end
    end
  end
end
