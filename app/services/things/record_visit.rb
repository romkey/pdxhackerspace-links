module Things
  class RecordVisit
    def self.call(thing:)
      thing.increment!(:visit_count)
    end
  end
end
