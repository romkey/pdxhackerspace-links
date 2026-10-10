class ThingTemplateApplicationsController < ApplicationController
  before_action :require_full_access
  before_action :set_thing
  before_action :set_thing_template

  def new
    @thing_templates = ThingTemplate.ordered
    # Applied in memory only, to preview what would be filled in.
    @filled = @thing_template.apply_to(@thing) if @thing_template
  end

  def create
    unless @thing_template
      redirect_to new_thing_template_application_path(@thing), alert: "Choose a template to apply."
      return
    end

    filled = @thing_template.apply_to(@thing)
    @thing.journal_message = "Applied template “#{@thing_template.name}”"
    if filled.empty?
      redirect_to thing_path(@thing), notice: "“#{@thing_template.name}” had nothing to fill in."
    elsif @thing.save
      redirect_to thing_path(@thing), notice: "Applied “#{@thing_template.name}”: filled in #{filled.to_sentence}."
    else
      redirect_to new_thing_template_application_path(@thing, template: @thing_template.id),
                  alert: @thing.errors.full_messages.to_sentence
    end
  end

  private

  def set_thing
    @thing = Thing.find_by_param!(params[:thing_id])
  end

  def set_thing_template
    @thing_template = ThingTemplate.find_by(id: params[:template]) if params[:template].present?
  end
end
