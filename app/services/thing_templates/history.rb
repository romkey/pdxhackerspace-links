module ThingTemplates
  # Reads a template's journal to find the values a thing made from it could
  # have inherited: the value in effect when the thing was made and every value
  # the template has held since.
  class History
    def initialize(template)
      @timelines = build_timelines(template.journal_entries.chronological)
    end

    def field_values(field, since:)
      values_since(@timelines["field:#{field}"], since)
    end

    def link_values(key, attribute, since:)
      values_since(@timelines["link:#{key}:#{attribute}"], since)
    end

    private

    def build_timelines(entries)
      timelines = Hash.new { |hash, key| hash[key] = [] }

      entries.each do |entry|
        at = entry.created_at
        entry.field_changes.each do |field, (old, new)|
          record(timelines["field:#{field}"], at, old, new)
        end
        entry.links_added.each do |link|
          %w[url note].each { |attribute| record(timelines["link:#{link['key']}:#{attribute}"], at, nil, link[attribute]) }
        end
        entry.links_removed.each do |link|
          %w[url note].each { |attribute| record(timelines["link:#{link['key']}:#{attribute}"], at, link[attribute], nil) }
        end
        entry.links_modified.each do |link|
          link["changes"].slice("url", "note").each do |attribute, (old, new)|
            record(timelines["link:#{link['key']}:#{attribute}"], at, old, new)
          end
        end
      end

      timelines
    end

    # A template saved before journals began has no entry for its first value,
    # so the first change found supplies it.
    def record(timeline, at, old, new)
      timeline << [ nil, old ] if timeline.empty? && !old.nil?
      timeline << [ at, new ]
    end

    def values_since(timeline, since)
      return [] if timeline.blank?

      timeline.each_with_index.filter_map do |(_at, value), index|
        replaced_at = timeline[index + 1]&.first
        value if replaced_at.nil? || since.nil? || replaced_at > since
      end.uniq
    end
  end
end
