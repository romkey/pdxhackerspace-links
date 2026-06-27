class AddNoteToThingLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :thing_links, :note, :text
  end
end
