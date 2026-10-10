module ThingTemplates
  # Brings the things made from a template up to date with it. A blank field or
  # link value is filled in, links the thing lacks are added, and a value is
  # replaced only while the thing still holds something the template used to
  # say. Anything changed by hand on the thing is left alone.
  class Refresh
    FIELD_MAP = { "name" => "thing_name" }.merge(ThingTemplate::FIELDS.to_h { |field| [ field.to_s, field.to_s ] }).freeze

    Result = Data.define(:updated, :unchanged, :failed)

    def self.call(template:)
      new(template: template).call
    end

    def initialize(template:)
      @template = template
    end

    def call
      history = History.new(template)
      updated = []
      failed = []
      unchanged = 0

      template.things.includes(:links).find_each do |thing|
        apply_fields(thing, history)
        apply_links(thing, history)

        if pending_changes?(thing)
          thing.journal_event = "refreshed"
          thing.journal_message = "Refreshed from template “#{template.name}”"
          thing.save ? updated << thing : failed << thing
        else
          unchanged += 1
        end
      end

      record_refresh(updated, failed, unchanged)
      Result.new(updated: updated, unchanged: unchanged, failed: failed)
    end

    private

    attr_reader :template

    def apply_fields(thing, history)
      FIELD_MAP.each do |thing_field, template_field|
        wanted = template[template_field]
        next if thing_field == "name" && wanted.blank?

        previous = history.field_values(template_field, since: linked_at(thing))
        thing[thing_field] = wanted if replace?(thing[thing_field], wanted, previous)
      end
    end

    def apply_links(thing, history)
      template.links.each do |data|
        link = matching_link(thing, data)

        if link.nil? || (link.url.blank? && link.note.blank?)
          add_link(thing, link, data)
        else
          key = ThingTemplate.link_key(data)
          %w[url note].each do |attribute|
            next if attribute == "url" && link.link_custom? && data["url"].blank?

            previous = history.link_values(key, attribute, since: linked_at(thing))
            link[attribute] = data[attribute] if replace?(link[attribute], data[attribute], previous)
          end
        end
      end
    end

    def linked_at(thing)
      thing.thing_template_linked_at || thing.created_at
    end

    def matching_link(thing, data)
      if data["link_type"] == "custom"
        title = data["title"].to_s.strip.downcase
        thing.custom_links.find { |link| link.title.to_s.strip.downcase == title }
      else
        thing.links.find { |link| link.link_type == data["link_type"] }
      end
    end

    def add_link(thing, link, data)
      if data["link_type"] == "custom"
        return if data["url"].blank?

        thing.links.build(link_type: :custom, title: data["title"], url: data["url"], note: data["note"],
                          position: thing.custom_links.size)
      else
        (link || thing.link_for(data["link_type"])).assign_attributes(url: data["url"], note: data["note"])
      end
    end

    def replace?(current, wanted, previous)
      current = Thing.journal_value(current)
      wanted = Thing.journal_value(wanted)
      return false if current == wanted
      return true if current.nil?

      previous.include?(current)
    end

    def pending_changes?(thing)
      thing.changed? || thing.links.any? { |link| link.new_record? || link.changed? }
    end

    def record_refresh(updated, failed, unchanged)
      total = updated.size + failed.size + unchanged
      message = "Refreshed #{updated.size} of #{total} #{'thing'.pluralize(total)}"
      message += ", #{failed.size} could not be saved" if failed.any?

      JournalEntry.create!(
        journalable: template,
        user: Current.user,
        event: "refreshed",
        message: message,
        details: { "things" => updated.map { |thing| { "id" => thing.id, "name" => thing.name } } }
      )
      template.journal_entries.reset
    end
  end
end
