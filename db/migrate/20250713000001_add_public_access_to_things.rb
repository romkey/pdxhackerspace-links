class AddPublicAccessToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :public_access, :boolean, default: false, null: false
  end
end
