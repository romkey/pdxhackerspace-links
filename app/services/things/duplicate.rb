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
          owner: thing.owner,
          ip_address: thing.ip_address
        )
        copy_links(copy)
        copy_photos(copy)
        copy
      end
    end

    private

    attr_reader :thing

    def copy_links(copy)
      thing.links.with_url.find_each do |link|
        if link.link_custom?
          copy.links.create!(
            link_type: :custom,
            title: link.title,
            url: link.url,
            position: link.position
          )
        else
          copy.links.create!(link_type: link.link_type, url: link.url)
        end
      end
    end

    def copy_photos(copy)
      thing.photos.each do |photo|
        copy.photos.attach(photo.blob)
      end
    end
  end
end
