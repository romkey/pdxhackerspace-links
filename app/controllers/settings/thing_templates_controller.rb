module Settings
  class ThingTemplatesController < BaseController
    before_action :set_thing_template, only: %i[edit update destroy refresh]

    def index
      @thing_templates = ThingTemplate.ordered
      @thing_counts = Thing.where.not(thing_template_id: nil).group(:thing_template_id).count
    end

    def edit
      load_edit_details
    end

    def update
      if @thing_template.update(thing_template_params)
        redirect_to settings_thing_templates_path, notice: "Template was updated."
      else
        load_edit_details
        render :edit, status: :unprocessable_entity
      end
    end

    def refresh
      result = ThingTemplates::Refresh.call(template: @thing_template)
      notice = "Updated #{result.updated.size} of #{@thing_template.things.size} " \
               "#{'thing'.pluralize(@thing_template.things.size)} from “#{@thing_template.name}”."
      flash[:alert] = "Could not save #{result.failed.map(&:name).to_sentence}." if result.failed.any?

      redirect_to edit_settings_thing_template_path(@thing_template), notice: notice
    end

    def destroy
      @thing_template.destroy!
      redirect_to settings_thing_templates_path, notice: "Template was deleted."
    end

    private

    def set_thing_template
      @thing_template = ThingTemplate.find(params[:id])
    end

    def load_edit_details
      @things = @thing_template.things.order(Arel.sql("lower(name)"))
      @journal_entries = @thing_template.journal_entries.includes(:user).limit(JournalEntriesHelper::JOURNAL_LIMIT)
    end

    def thing_template_params
      params.require(:thing_template).permit(:name, :thing_name, *ThingTemplate::FIELDS)
    end
  end
end
