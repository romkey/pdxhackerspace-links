class AddLabelNameToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :label_name, :string
  end
end
