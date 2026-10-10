module Settings
  class ThingTemplatesController < BaseController
    before_action :set_thing_template, only: %i[edit update destroy]

    def index
      @thing_templates = ThingTemplate.ordered
    end

    def edit
    end

    def update
      if @thing_template.update(thing_template_params)
        redirect_to settings_thing_templates_path, notice: "Template was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @thing_template.destroy!
      redirect_to settings_thing_templates_path, notice: "Template was deleted."
    end

    private

    def set_thing_template
      @thing_template = ThingTemplate.find(params[:id])
    end

    def thing_template_params
      params.require(:thing_template).permit(:name, :thing_name, *ThingTemplate::FIELDS)
    end
  end
end
