class AddLabelledAtToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :labelled_at, :datetime
    add_index :things, :labelled_at
  end
end
