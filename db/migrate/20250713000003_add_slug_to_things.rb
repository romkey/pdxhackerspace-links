class AddSlugToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :slug, :string
    add_index :things, :slug, unique: true, where: "slug IS NOT NULL"
  end
end
