module Settings
  class BaseController < ApplicationController
    before_action :require_signed_in_user

    layout "application"

    private

    def unlink_notice(record, thing)
      if thing
        "#{record.display_name} is no longer linked to #{thing.name}."
      else
        "#{record.display_name} is not linked to a thing."
      end
    end

    def link_notice(record)
      if record.thing
        "#{record.display_name} is linked to #{record.thing.name}."
      else
        "#{record.display_name} will be linked when a matching thing exists."
      end
    end
  end
end
