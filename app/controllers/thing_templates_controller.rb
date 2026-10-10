class ThingTemplatesController < ApplicationController
  before_action :require_full_access
  before_action :set_thing

  def new
    @thing_template = ThingTemplate.new(name: @thing.name)
  end

  def create
    @thing_template = ThingTemplate.from_thing(@thing, name: params.dig(:thing_template, :name))
    replacing = @thing_template.persisted?

    if @thing_template.save
      verb = replacing ? "Replaced" : "Saved"
      redirect_to thing_path(@thing), notice: "#{verb} template “#{@thing_template.name}”."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_thing
    @thing = Thing.find_by_param!(params[:thing_id])
  end
end
