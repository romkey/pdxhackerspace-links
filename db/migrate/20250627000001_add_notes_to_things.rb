class AddNotesToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :notes, :text
  end
end
