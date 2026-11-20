# Things can be marked as needing training before use, and get a standard
# "Request training" link pointing at wherever people sign up for it.
class AddTrainingRequiredToThings < ActiveRecord::Migration[8.1]
  def up
    add_column :things, :training_required, :boolean, default: false, null: false
    add_column :thing_templates, :training_required, :boolean, default: false, null: false
    add_index :things, :training_required, where: "training_required"

    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('wiki', 'slack', 'where', 'ar', 'training')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
  end

  def down
    execute "DELETE FROM thing_links WHERE link_type = 'training'"
    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('wiki', 'slack', 'where', 'ar')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"

    remove_index :things, :training_required
    remove_column :thing_templates, :training_required
    remove_column :things, :training_required
  end
end
