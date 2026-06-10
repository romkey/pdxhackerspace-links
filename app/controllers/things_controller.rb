class ThingsController < ApplicationController
  before_action :set_thing, only: %i[show edit update destroy purge_photo]

  def index
    @search_query = params[:q].to_s.strip.presence
    @things = Thing.search(@search_query).order(:name)
  end

  def show
  end

  def new
    @thing = Thing.new
    @thing.links.build(link_type: :custom, position: 0)
  end

  def edit
    @thing.links.build(link_type: :custom, position: next_custom_link_position) if @thing.custom_links.empty?
  end

  def create
    @thing = Thing.new(thing_params)

    if @thing.save
      redirect_to @thing, notice: "Thing was created."
    else
      ensure_custom_link_fields
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @thing.update(thing_params)
      redirect_to @thing, notice: "Thing was updated."
    else
      ensure_custom_link_fields
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @thing.destroy!
    redirect_to things_path, notice: "Thing was deleted."
  end

  def purge_photo
    photo = @thing.photos.find(params[:photo_id])
    photo.purge
    redirect_to @thing, notice: "Photo was removed."
  end

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(
      :name,
      :description,
      photos: [],
      links_attributes: %i[id link_type title url position _destroy]
    )
  end

  def next_custom_link_position
    (@thing.custom_links.map(&:position).compact.max || -1) + 1
  end

  def ensure_custom_link_fields
    return if @thing.links.any?(&:link_custom?)

    @thing.links.build(link_type: :custom, position: next_custom_link_position)
  end
end
