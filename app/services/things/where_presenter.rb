module Things
  class WherePresenter
    attr_reader :link

    def initialize(link)
      @link = link
    end

    def label
      link.note.presence || "Where"
    end

    def href
      link.safe_href
    end

    def affordance
      "Open in geowiki"
    end
  end
end
