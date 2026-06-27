class AddArAnchorNoteToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :ar_anchor_note, :text
  end
end
