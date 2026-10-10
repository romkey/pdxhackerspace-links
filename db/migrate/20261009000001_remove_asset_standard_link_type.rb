# Things are the asset manager now, so the standard Asset link goes away.
# Existing Asset links become custom links titled "Asset" at the end of each
# thing's custom links, so no URL or note is lost.
class RemoveAssetStandardLinkType < ActiveRecord::Migration[8.1]
  def up
    # Blank Asset links were placeholders, not links; custom links need a URL.
    execute "DELETE FROM thing_links WHERE link_type = 'asset' AND COALESCE(url, '') = ''"

    execute <<~SQL.squish
      UPDATE thing_links
      SET link_type = 'custom',
          title = 'Asset',
          position = COALESCE((
            SELECT MAX(custom_links.position) + 1
            FROM thing_links custom_links
            WHERE custom_links.thing_id = thing_links.thing_id
              AND custom_links.link_type = 'custom'
          ), 0)
      WHERE link_type = 'asset'
    SQL

    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('wiki', 'slack', 'where', 'ar')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
  end

  def down
    remove_index :thing_links, name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id link_type],
              unique: true,
              where: "link_type IN ('asset', 'wiki', 'slack', 'where', 'ar')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
  end
end
