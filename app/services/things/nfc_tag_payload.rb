module Things
  class NfcTagPayload
    Result = Data.define(:url, :json, :json_truncated, :estimated_bytes)

    MIME_TYPE = "application/json"
    TRUNCATION_SUFFIX = "…"
    DEFAULT_MAX_BYTES = 496
    TRUNCATABLE_FIELDS = %i[description notes name owner].freeze

    include Rails.application.routes.url_helpers

    def self.call(thing)
      new(thing).call
    end

    def initialize(thing)
      @thing = thing
    end

    def call
      url = thing_url(@thing, **route_url_options)
      fields = build_fields(url)
      original_fields = fields.dup

      loop do
        break if estimated_size(url, fields, original_fields) <= max_bytes
        break unless apply_next_truncation(fields)
      end

      mark_truncated_fields!(fields, original_fields)

      json = JSON.generate(fields)
      Result.new(
        url: url,
        json: json,
        json_truncated: fields != original_fields,
        estimated_bytes: estimated_size(url, fields, original_fields)
      )
    end

    private

    def estimated_size(url, fields, original_fields = fields)
      marked = fields.dup
      mark_truncated_fields!(marked, original_fields) if fields != original_fields
      estimate_ndef_bytes(url, marked)
    end

    def build_fields(url)
      {
        url: url,
        name: @thing.name.to_s,
        owner: @thing.owner.to_s,
        ip_address: @thing.ip_address.to_s,
        description: @thing.description.to_s,
        notes: @thing.notes.to_s
      }.compact_blank
    end

    def apply_next_truncation(fields)
      TRUNCATABLE_FIELDS.each do |key|
        return true if shrink_field(fields, key)
      end

      false
    end

    def shrink_field(fields, key)
      value = fields[key]
      return false if value.blank?

      fields[key] = value.length <= 1 ? "" : value[0...-1].rstrip
      true
    end

    def mark_truncated_fields!(fields, original_fields)
      TRUNCATABLE_FIELDS.each do |key|
        next if fields[key] == original_fields[key]
        next if fields[key].blank?
        next unless fields[key].length < original_fields[key].length

        fields[key] = "#{fields[key]}#{TRUNCATION_SUFFIX}" unless fields[key].end_with?(TRUNCATION_SUFFIX)
      end
    end

    def max_bytes
      ENV.fetch("NFC_TAG_MAX_BYTES", DEFAULT_MAX_BYTES).to_i
    end

    def route_url_options
      Rails.application.config.action_mailer.default_url_options.symbolize_keys
    end

    def estimate_ndef_bytes(url, fields)
      estimate_uri_record_bytes(url) + estimate_mime_record_bytes(JSON.generate(fields))
    end

    def estimate_uri_record_bytes(url)
      payload_length = uri_payload_length(url)
      record_overhead(payload_length, type_length: 1) + payload_length
    end

    def uri_payload_length(url)
      1 + url.bytesize - uri_prefix_saved_bytes(url)
    end

    def uri_prefix_saved_bytes(url)
      case url
      when %r{\Ahttps://www\.} then 12
      when %r{\Ahttp://www\.} then 11
      when %r{\Ahttps://} then 8
      when %r{\Ahttp://} then 7
      else 0
      end
    end

    def estimate_mime_record_bytes(json_body)
      payload_length = json_body.bytesize
      record_overhead(payload_length, type_length: MIME_TYPE.bytesize) + payload_length
    end

    def record_overhead(payload_length, type_length:, id_length: 0)
      header = payload_length > 255 ? 6 : 3
      header += 1 if id_length.positive?

      header + type_length + id_length
    end
  end
end
