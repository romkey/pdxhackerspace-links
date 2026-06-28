class AddArStandardLinkType < ActiveRecord::Migration[8.1]
  def up
    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('asset', 'wiki', 'slack', 'where', 'ar')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
  end

  def down
    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('asset', 'wiki', 'slack', 'where')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
  end
end
