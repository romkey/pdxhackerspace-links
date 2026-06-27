class ThingsController < ApplicationController
  before_action :require_full_access, only: %i[new create edit update destroy duplicate purge_photo purge_ar_anchor print label_preview]
  before_action :set_thing, only: %i[show edit update destroy duplicate purge_photo purge_ar_anchor print label_preview]
  before_action :load_printers, only: %i[index show label_preview], if: :can_manage_things?

  def index
    @search_query = params[:q].to_s.strip.presence
    @things = Thing.search(@search_query).order(:name)
  end

  def show
    if ThingTracking.tracked?(params[:utm_source])
      Things::RecordScan.call(thing: @thing, utm_source: params[:utm_source])
      Things::RecordVisit.call(thing: @thing)
      store_tracked_redirect_in_session
      session[:skip_visit_count_for] = @thing.id
      redirect_to thing_path(@thing), status: :see_other
      return
    end

    Things::RecordVisit.call(thing: @thing) unless skip_visit_count?
    load_tracked_redirect_from_session
  end

  def print
    printer = Printer.enabled.find(params[:printer_id])
    copies = params[:copies].to_i
    copies = 1 if copies < 1

    Things::PrintLabel.call(thing: @thing, printer: printer, copies: copies)
    redirect_back_or_to thing_path(@thing), notice: "Sent “#{@thing.name}” to #{printer.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_back_or_to thing_path(@thing), alert: "Printer not found or disabled."
  rescue Cups::Client::Error, Printers::CommandError => error
    redirect_back_or_to thing_path(@thing), alert: error.message
  end

  def label_preview
    @printer = Printer.enabled.find(params[:printer_id])
    @label = label_renderer_for(@printer)
    @thing_qr_url = ThingTracking.thing_url(@thing, utm_source: ThingTracking::QR_CODE)

    respond_to do |format|
      format.html
      format.pdf do
        redirect_to label_preview_thing_path(@thing, printer_id: @printer.id, format: :png), allow_other_host: false if @printer.command?

        prevent_label_preview_caching
        send_data @label.pdf_data,
                  filename: label_preview_filename(@printer, "pdf"),
                  type: "application/pdf",
                  disposition: "inline"
      end
      format.png do
        redirect_to label_preview_thing_path(@thing, printer_id: @printer.id, format: :pdf), allow_other_host: false unless @printer.command?

        prevent_label_preview_caching
        send_data @label.png_data,
                  filename: label_preview_filename(@printer, "png"),
                  type: "image/png",
                  disposition: "inline"
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back_or_to thing_path(@thing), alert: "Printer not found or disabled."
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

  def duplicate
    copy = Things::Duplicate.call(thing: @thing)
    redirect_to edit_thing_path(copy), notice: "Duplicated as “#{copy.name}”."
  end

  def purge_photo
    photo = @thing.photos.find(params[:photo_id])
    photo.purge
    redirect_to @thing, notice: "Photo was removed."
  end

  def purge_ar_anchor
    @thing.ar_anchor.purge
    redirect_back_or_to @thing, notice: "AR marker was removed."
  end

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(
      :name,
      :description,
      :notes,
      :owner,
      :ip_address,
      :ar_anchor_note,
      :ar_anchor,
      photos: [],
      links_attributes: %i[id link_type title url note position _destroy]
    )
  end

  def next_custom_link_position
    (@thing.custom_links.map(&:position).compact.max || -1) + 1
  end

  def ensure_custom_link_fields
    return if @thing.links.any?(&:link_custom?)

    @thing.links.build(link_type: :custom, position: next_custom_link_position)
  end

  def load_printers
    @printers = Printer.enabled.ordered
  end

  def label_preview_filename(printer, extension)
    "#{@thing.name.parameterize}-#{printer.name.parameterize}.#{extension}"
  end

  def label_renderer_for(printer)
    if printer.command?
      Things::LabelPng.new(thing: @thing, printer: printer)
    else
      Things::LabelPdf.new(thing: @thing, printer: printer)
    end
  end

  def prevent_label_preview_caching
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def skip_visit_count?
    session.delete(:skip_visit_count_for) == @thing.id
  end

  def store_tracked_redirect_in_session
    links = @thing.links_with_urls
    return unless links.size == 1

    url = links.first.safe_href
    return if url.blank?

    session[:thing_tracked_redirect] = {
      "thing_id" => @thing.id,
      "url" => url,
      "title" => links.first.display_title,
      "seconds" => ThingTracking::REDIRECT_SECONDS
    }
  end

  def load_tracked_redirect_from_session
    payload = session.delete(:thing_tracked_redirect)
    return unless payload
    return unless payload["thing_id"] == @thing.id

    @tracked_redirect = {
      url: payload["url"],
      title: payload["title"],
      seconds: payload["seconds"]
    }
  end
end
