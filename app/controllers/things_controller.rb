class ThingsController < ApplicationController
  MAX_BULK_LABELS = 100

  skip_before_action :require_login, only: %i[show by_beacon]
  before_action :require_full_access, only: %i[
    new create edit update destroy duplicate purge_photo purge_ar_anchor
    print label_preview update_labelled bulk_print bulk_label_preview
  ]
  before_action :set_thing, only: %i[
    show edit update destroy duplicate purge_photo purge_ar_anchor print label_preview update_labelled
  ]
  before_action :set_thing_by_beacon, only: :by_beacon
  before_action :require_login_or_public_thing, only: %i[show by_beacon]
  before_action :load_printers, only: %i[index show label_preview bulk_label_preview], if: :can_manage_things?
  before_action :load_unifi_devices, only: :show, if: :can_manage_things?
  before_action :load_zigbee2mqtt_devices, only: :show, if: :can_manage_things?

  def index
    @search_query = params[:q].to_s.strip.presence
    @things_index = Things::IndexQuery.call(
      search: @search_query,
      sort: params[:sort],
      direction: params[:direction],
      admin: can_manage_things?,
      filters: params[:filter]
    )
    @pagy, @things = pagy(
      @things_index.scope,
      limit: Pagy::DEFAULT[:limit],
      count: @things_index.total_count
    )
  end

  def show
    if params[:key].present?
      utm_source = ThingTracking.scan_utm_source_from(params)
      if utm_source
        redirect_to ThingTracking.full_thing_url(@thing, utm_source: utm_source),
                    allow_other_host: true,
                    status: :found
        return
      end
    end

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

  def by_beacon
    redirect_to thing_path(@thing), status: :see_other
  end

  def print
    printer = Printer.enabled.find(params[:printer_id])
    layout = label_layout_param
    return unless validate_label_layout!(printer, layout, thing: @thing)

    copies = copies_param

    Things::PrintLabel.call(
      thing: @thing,
      printer: printer,
      copies: copies,
      layout: layout,
      margins: label_margin_params,
      mark_labelled: mark_labelled_param?
    )
    notice = print_notice(@thing.name, printer.name, layout)
    redirect_back_or_to thing_path(@thing), notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_back_or_to thing_path(@thing), alert: "Printer not found or disabled."
  rescue ArgumentError => error
    redirect_back_or_to thing_path(@thing), alert: error.message
  rescue Cups::Client::Error, Printers::CommandError => error
    redirect_back_or_to thing_path(@thing), alert: error.message
  end

  def bulk_print
    printer = Printer.enabled.find(params[:printer_id])
    layout = label_layout_param
    return unless validate_bulk_label_layout!(printer, layout)

    thing_ids, skipped = resolve_bulk_print_ids(layout)
    if thing_ids.empty?
      redirect_back_or_to things_path, alert: bulk_empty_alert(layout, skipped)
      return
    end

    if thing_ids.size > MAX_BULK_LABELS
      redirect_back_or_to things_path, alert: "Select at most #{MAX_BULK_LABELS} things to print."
      return
    end

    Things::BulkPrintJob.perform_later(
      thing_ids: thing_ids,
      printer_id: printer.id,
      layout: layout.to_s,
      copies: copies_param,
      mark_labelled: mark_labelled_param?
    )

    notice = "Queued #{thing_ids.size} #{'label'.pluralize(thing_ids.size)} for printing on #{printer.name}."
    notice += " Skipped #{skipped} without IP or hostname." if skipped.positive? && layout == :cable_tag
    redirect_back_or_to things_path, notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_back_or_to things_path, alert: "Printer not found or disabled."
  end

  def bulk_label_preview
    @printer = Printer.enabled.find(params[:printer_id])
    @layout = label_layout_param
    return unless validate_bulk_label_layout!(@printer, @layout)

    thing_ids, @skipped_count = resolve_bulk_print_ids(@layout)
    if thing_ids.empty?
      redirect_back_or_to things_path, alert: bulk_empty_alert(@layout, @skipped_count)
      return
    end

    if thing_ids.size > MAX_BULK_LABELS
      redirect_back_or_to things_path, alert: "Select at most #{MAX_BULK_LABELS} things to preview."
      return
    end

    things_by_id = Thing.where(id: thing_ids).index_by(&:id)
    @things = thing_ids.filter_map { |id| things_by_id[id] }
    @preview_params = bulk_label_preview_query_params
    @preview_media_format = @printer.command? ? :png : :pdf
    @label_entries = @things.map do |thing|
      label = label_renderer_for(@printer, thing: thing, layout: @layout, margins: label_margin_params)
      {
        thing: thing,
        label: label,
        media_path: label_preview_thing_path(
          thing,
          printer_id: @printer.id,
          **@preview_params,
          format: @preview_media_format
        )
      }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back_or_to things_path, alert: "Printer not found or disabled."
  end

  def update_labelled
    if params[:labelled].to_s == "1"
      @thing.mark_labelled!
      notice = "Marked “#{@thing.name}” as labelled."
    else
      @thing.unmark_labelled!
      notice = "Marked “#{@thing.name}” as not labelled."
    end

    redirect_back_or_to thing_path(@thing), notice: notice
  end

  def label_preview
    @printer = Printer.enabled.find(params[:printer_id])
    @layout = label_layout_param
    return unless validate_label_layout!(@printer, @layout, thing: @thing)

    @margin_overrides = label_margin_params
    @label = label_renderer_for(@printer, layout: @layout, margins: @margin_overrides)
    @thing_qr_url = ThingTracking.thing_url(@thing, utm_source: ThingTracking::QR_CODE)
    @preview_params = label_preview_query_params

    respond_to do |format|
      format.html
      format.pdf do
        redirect_to label_preview_thing_path(@thing, printer_id: @printer.id, format: :png, **@preview_params), allow_other_host: false if @printer.command?

        prevent_label_preview_caching
        send_data @label.pdf_data,
                  filename: label_preview_filename(@printer, "pdf"),
                  type: "application/pdf",
                  disposition: "inline"
      end
      format.png do
        redirect_to label_preview_thing_path(@thing, printer_id: @printer.id, format: :pdf, **@preview_params), allow_other_host: false unless @printer.command?

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
    @thing = Thing.find_by_param!(params[:id] || params[:key])
  end

  def set_thing_by_beacon
    uuid = params[:ble_beacon_uuid].to_s.strip.downcase
    @thing = Thing.find_by!(ble_beacon_uuid: uuid)
  end

  def thing_params
    params.require(:thing).permit(
      :name,
      :slug,
      :description,
      :notes,
      :owner,
      :ip_address,
      :hostname,
      :ieee_address,
      :manufacturer,
      :model,
      :manufacturer_url,
      :ble_beacon_uuid,
      :ar_anchor_note,
      :public_access,
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

  def load_unifi_devices
    @unifi_devices = @thing&.unifi_devices&.includes(:unifi_controller)&.ordered
  end

  def load_zigbee2mqtt_devices
    @zigbee2mqtt_devices = @thing&.zigbee2mqtt_devices&.includes(:zigbee2mqtt_bridge)&.ordered
  end

  def label_preview_filename(printer, extension)
    suffix = @layout == :standard ? "" : "-#{@layout.to_s.dasherize}"
    "#{@thing.name.parameterize}-#{printer.name.parameterize}#{suffix}.#{extension}"
  end

  def label_renderer_for(printer, layout: :standard, margins: nil, thing: @thing)
    if printer.command?
      Things::LabelPng.new(thing: thing, printer: printer, layout: layout, margins: margins)
    else
      Things::LabelPdf.new(thing: thing, printer: printer, layout: layout, margins: margins)
    end
  end

  def label_layout_param
    layout = params[:layout].to_s.presence || "standard"
    sym = layout.to_sym
    Things::LabelPdf::LAYOUTS.include?(sym) ? sym : :standard
  end

  def validate_label_layout!(printer, layout, thing:)
    unless Things::LabelPdf::LAYOUTS.include?(layout)
      redirect_back_or_to thing_path(thing), alert: "Invalid label layout."
      return false
    end

    if layout == :cable_tag
      unless printer.cable_tag_capable?
        redirect_back_or_to thing_path(thing), alert: "This printer does not support cable tags."
        return false
      end
      unless thing.cable_tag_printable?
        redirect_back_or_to thing_path(thing), alert: "Cable tags require an IP address or hostname."
        return false
      end
    end

    true
  end

  def validate_bulk_label_layout!(printer, layout)
    unless Things::LabelPdf::LAYOUTS.include?(layout)
      redirect_back_or_to things_path, alert: "Invalid label layout."
      return false
    end

    if layout == :cable_tag && !printer.cable_tag_capable?
      redirect_back_or_to things_path, alert: "This printer does not support cable tags."
      return false
    end

    true
  end

  def resolve_bulk_print_ids(layout)
    scope = if params[:select_all].to_s == "1"
      Things::IndexQuery.filtered_scope(search: params[:q], filters: params[:filter])
    else
      Thing.where(id: Array(params[:thing_ids]).map(&:to_i))
    end

    things = scope.distinct.to_a
    skipped = 0

    if layout == :cable_tag
      eligible = things.select(&:cable_tag_printable?)
      skipped = things.size - eligible.size
      things = eligible
    end

    [ things.map(&:id), skipped ]
  end

  def bulk_empty_alert(layout, skipped)
    if layout == :cable_tag && skipped.positive?
      "No selected things have an IP address or hostname for cable tags."
    else
      "Select at least one thing to print."
    end
  end

  def copies_param
    copies = params[:copies].to_i
    copies = 1 if copies < 1
    copies
  end

  def mark_labelled_param?
    params[:mark_labelled].to_s.in?(%w[1 true on])
  end

  def print_notice(thing_name, printer_name, layout)
    layout_label = Things::LabelPdf.layout_label(layout)
    "Sent #{layout_label.downcase} for “#{thing_name}” to #{printer_name}."
  end

  def prevent_label_preview_caching
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def label_margin_params
    overrides = {}
    %i[left_margin_mm right_margin_mm cable_tag_gap_mm].each do |key|
      value = params[key]
      next if value.blank?

      overrides[key] = value.to_f
    end
    overrides.presence
  end

  def label_preview_query_params
    params_hash = {}
    params_hash[:layout] = @layout unless @layout == :standard
    params_hash[:mark_labelled] = "1" if mark_labelled_param?
    label_margin_params&.each do |key, value|
      params_hash[key] = value
    end
    params_hash
  end

  def bulk_label_preview_query_params
    params_hash = {}
    params_hash[:layout] = @layout unless @layout == :standard
    label_margin_params&.each do |key, value|
      params_hash[key] = value
    end
    params_hash
  end

  def skip_visit_count?
    session.delete(:skip_visit_count_for) == @thing.id
  end

  def require_login_or_public_thing
    return if logged_in?
    return if network_whitelist_access?
    return if @thing.public_access?

    redirect_to login_path, alert: "Please sign in to continue."
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
