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
        copy = Thing.create!(
          name: "#{thing.name} (duplicate)",
          description: thing.description,
          notes: thing.notes,
          owner: thing.owner,
          ip_address: thing.ip_address,
          ar_anchor_note: thing.ar_anchor_note
        )
        copy_links(copy)
        copy_photos(copy)
        copy_ar_anchor(copy)
        copy
      end
    end

    private

    attr_reader :thing

    def copy_links(copy)
      thing.links_for_display.each do |link|
        if link.link_custom?
          copy.links.create!(
            link_type: :custom,
            title: link.title,
            url: link.url,
            note: link.note,
            position: link.position
          )
        else
          copy.links.create!(link_type: link.link_type, url: link.url, note: link.note)
        end
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
