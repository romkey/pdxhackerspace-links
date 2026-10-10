module Things
  class Duplicate
    def self.call(thing:)
      new(thing: thing).call
    end

    def initialize(thing:)
      @thing = thing
    end

    def call
      Thing.transaction do
        copy = Thing.new(
          name: "#{thing.name} (duplicate)",
          description: thing.description,
          notes: thing.notes,
          owner: thing.owner,
          ip_address: thing.ip_address,
          hostname: thing.hostname,
          manufacturer: thing.manufacturer,
          model: thing.model,
          manufacturer_url: thing.manufacturer_url,
          ar_anchor_note: thing.ar_anchor_note,
          thing_template_id: thing.thing_template_id
        )
        copy_links(copy)
        copy.journal_message = "Duplicated from “#{thing.name}”"
        copy.save!
        copy_relationships(copy)
        copy_photos(copy)
        copy_ar_anchor(copy)
        copy
      end
    end

    private

    attr_reader :thing

    # Built rather than created so the copy's journal records them with it.
    def copy_links(copy)
      thing.links.select { |link| link.present_link? || link.standard_note? }.each do |link|
        if link.link_custom?
          copy.links.build(
            link_type: :custom,
            title: link.title,
            url: link.url,
            note: link.note,
            position: link.position
          )
        else
          copy.link_for(link.link_type).assign_attributes(url: link.url, note: link.note)
        end
      end
    end

    def copy_relationships(copy)
      thing.related_things_for_display.each do |relationship|
        copy.thing_relationships.create!(
          related_thing: relationship.related_thing,
          note: relationship.note
        )
      end
    end

    def copy_photos(copy)
      thing.photos.each do |photo|
        copy.photos.attach(photo.blob)
      end
    end

    def copy_ar_anchor(copy)
      return unless thing.ar_anchor.attached?

      copy.ar_anchor.attach(thing.ar_anchor.blob)
    end
  end
end
