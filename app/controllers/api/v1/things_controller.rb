module Api
  module V1
    class ThingsController < BaseController
      DEFAULT_PER_PAGE = 100
      MAX_PER_PAGE = 500

      def index
        scope = Thing.order(:id)
        if params[:updated_since].present?
          since = parse_time(params[:updated_since])
          return render json: { error: "updated_since must be an ISO 8601 time" }, status: :bad_request unless since

          scope = scope.where(updated_at: since..)
        end

        pagy, things = pagy(:offset, scope, limit: per_page, page: page)
        things = ThingSerializer.preload(things)

        render json: {
          things: things.map { |thing| ThingSerializer.new(thing, urls: self).as_json },
          pagination: {
            page: pagy.page,
            per_page: pagy.limit,
            count: pagy.count,
            pages: pagy.last,
            next: pagy.next
          }
        }
      end

      def show
        thing = Thing.find_by_param!(params[:id])
        thing = ThingSerializer.preload(Thing.where(id: thing.id)).first

        render json: { thing: ThingSerializer.new(thing, urls: self).as_json }
      end

      private

      def per_page
        value = params[:per_page].to_i
        value.positive? ? [ value, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
      end

      def page
        [ params[:page].to_i, 1 ].max
      end

      def parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
