require 'action_view/testing/resolvers'

RSpec.configure do |config|
  # This allows us to expose `render_views` as a config option even though it
  # breaks the convention of other options by using `render_views` as a
  # command (i.e. render_views = true), where it would normally be used as a
  # getter. This makes it easier for rspec-rails users because we use
  # `render_views` directly in example groups, so this aligns the two APIs,
  # but requires this workaround:
  config.add_setting :rendering_views, :default => false

  def config.render_views=(val)
    self.rendering_views = val
  end

  def config.render_views
    self.rendering_views = true
  end

  def config.render_views?
    rendering_views
  end
end

module RSpec
  module Rails
    module ViewRendering
      extend ActiveSupport::Concern

      attr_accessor :controller

      module ClassMethods
        def metadata_for_rspec_rails
          metadata[:rspec_rails] = metadata[:rspec_rails] ? metadata[:rspec_rails].dup : {}
        end

        # @see RSpec::Rails::ControllerExampleGroup
        def render_views(true_or_false=true)
          metadata_for_rspec_rails[:render_views] = true_or_false
        end

        # @deprecated Use `render_views` instead.
        def integrate_views
          RSpec.deprecate("integrate_views", :replacement => "render_views")
          render_views
        end

        # @api private
        def render_views?
          metadata_for_rspec_rails.fetch(:render_views) do
            RSpec.configuration.render_views?
          end
        end
      end

      # @api private
      def render_views?
        self.class.render_views? || !controller.class.respond_to?(:view_paths)
      end

      # Delegates find_all to the submitted path set and then returns templates
      # with modified source
      #
      # @private
      class EmptyTemplateResolver < ::ActionView::FileSystemResolver
      private

        def find_templates(*args)
          super.map do |template|
            ::ActionView::Template.new(
              "",
              template.identifier,
              EmptyTemplateHandler,
              {
                :virtual_path => template.virtual_path,
                :format => template.formats
              }
            )
          end
        end
      end

      class EmptyTemplateHandler
        def self.call(template)
          %("")
        end
      end

      module EmptyTemplates
        # @api private
        def prepend_view_path(new_path)
          lookup_context.view_paths.unshift(*_path_decorator(new_path))
        end

        # @api private
        def append_view_path(new_path)
          lookup_context.view_paths.push(*_path_decorator(new_path))
        end

        private

        def _path_decorator(path)
          EmptyTemplateResolver.new(path)
        end
      end

      included do
        before do
          unless render_views?
            @_original_path_set = controller.class.view_paths

            empty_template_path_set = @_original_path_set.map do |resolver|
              EmptyTemplateResolver.new(resolver.to_s)
            end

            controller.class.view_paths = empty_template_path_set
            controller.extend(EmptyTemplates)
          end
        end

        after do
          controller.class.view_paths = @_original_path_set unless render_views?
        end
      end
    end
  end
end
