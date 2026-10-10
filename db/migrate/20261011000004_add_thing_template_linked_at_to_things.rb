# Refresh needs to know when a thing started following its template. That is
# not always its created_at: duplicates and merges carry the link over from
# another thing.
class AddThingTemplateLinkedAtToThings < ActiveRecord::Migration[8.1]
  def up
    add_column :things, :thing_template_linked_at, :datetime
    execute "UPDATE things SET thing_template_linked_at = created_at WHERE thing_template_id IS NOT NULL"
  end

  def down
    remove_column :things, :thing_template_linked_at
  end
end
