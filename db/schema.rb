# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_19_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "printers", force: :cascade do |t|
    t.string "avery_template"
    t.datetime "created_at", null: false
    t.string "cups_name"
    t.string "cups_server"
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.integer "label_height_mm"
    t.string "name", null: false
    t.string "page_size"
    t.boolean "precut_before", default: false, null: false
    t.text "print_command"
    t.string "printer_type", default: "cups", null: false
    t.datetime "updated_at", null: false
    t.index ["cups_server", "cups_name"], name: "index_printers_on_cups_server_and_cups_name", unique: true
    t.index ["cups_server"], name: "index_printers_on_cups_server"
    t.index ["enabled"], name: "index_printers_on_enabled"
    t.index ["name"], name: "index_printers_on_name"
    t.index ["printer_type"], name: "index_printers_on_printer_type"
  end

  create_table "site_settings", force: :cascade do |t|
    t.decimal "cable_tag_gap_mm", precision: 5, scale: 2, default: "10.0", null: false
    t.datetime "created_at", null: false
    t.string "cups_server", default: "localhost:631", null: false
    t.decimal "label_print_left_margin_mm", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "label_print_right_margin_mm", precision: 5, scale: 2, default: "3.0", null: false
    t.string "matomo_site_id"
    t.string "matomo_url"
    t.datetime "updated_at", null: false
  end

  create_table "thing_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "link_type", null: false
    t.text "note"
    t.integer "position"
    t.bigint "thing_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["thing_id", "link_type"], name: "index_thing_links_on_thing_id_and_standard_link_type", unique: true, where: "((link_type)::text = ANY (ARRAY[('asset'::character varying)::text, ('wiki'::character varying)::text, ('slack'::character varying)::text, ('where'::character varying)::text, ('ar'::character varying)::text]))"
    t.index ["thing_id", "position"], name: "index_thing_links_on_thing_id_and_position"
    t.index ["thing_id"], name: "index_thing_links_on_thing_id"
  end

  create_table "things", force: :cascade do |t|
    t.text "ar_anchor_note"
    t.string "ble_beacon_uuid"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "hostname"
    t.string "ip_address"
    t.string "key", null: false
    t.string "mac_address"
    t.string "name", null: false
    t.integer "nfc_scan_count", default: 0, null: false
    t.text "notes"
    t.string "owner"
    t.boolean "public_access", default: false, null: false
    t.integer "qr_scan_count", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.integer "visit_count", default: 0, null: false
    t.index ["ble_beacon_uuid"], name: "index_things_on_ble_beacon_uuid", unique: true, where: "(ble_beacon_uuid IS NOT NULL)"
    t.index ["key"], name: "index_things_on_key", unique: true
    t.index ["mac_address"], name: "index_things_on_mac_address", unique: true, where: "(mac_address IS NOT NULL)"
    t.index ["name"], name: "index_things_on_name"
    t.index ["slug"], name: "index_things_on_slug", unique: true, where: "(slug IS NOT NULL)"
  end

  create_table "unifi_controllers", force: :cascade do |t|
    t.text "api_key", null: false
    t.boolean "auto_create_things", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "host", null: false
    t.text "last_sync_message"
    t.string "last_sync_status"
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.boolean "network_enabled", default: true, null: false
    t.integer "port", default: 443, null: false
    t.boolean "protect_enabled", default: true, null: false
    t.datetime "updated_at", null: false
    t.boolean "verify_tls", default: false, null: false
    t.index ["enabled"], name: "index_unifi_controllers_on_enabled"
    t.index ["host", "port"], name: "index_unifi_controllers_on_host_and_port", unique: true
    t.index ["name"], name: "index_unifi_controllers_on_name", unique: true
  end

  create_table "unifi_devices", force: :cascade do |t|
    t.jsonb "applied_attributes", default: {}, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "firmware_version"
    t.datetime "first_seen_at", null: false
    t.boolean "ignored", default: false, null: false
    t.string "ip_address"
    t.string "kind", null: false
    t.datetime "last_seen_at", null: false
    t.string "mac_address"
    t.string "model"
    t.string "name"
    t.jsonb "payload", default: {}, null: false
    t.string "site_external_id"
    t.string "site_name"
    t.string "source", null: false
    t.string "state"
    t.bigint "thing_id"
    t.bigint "unifi_controller_id", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_unifi_devices_on_archived_at"
    t.index ["mac_address"], name: "index_unifi_devices_on_mac_address"
    t.index ["source"], name: "index_unifi_devices_on_source"
    t.index ["thing_id"], name: "index_unifi_devices_on_thing_id"
    t.index ["unifi_controller_id", "source", "external_id"], name: "index_unifi_devices_on_controller_source_and_external_id", unique: true
    t.index ["unifi_controller_id"], name: "index_unifi_devices_on_unifi_controller_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "thing_links", "things"
  add_foreign_key "unifi_devices", "things"
  add_foreign_key "unifi_devices", "unifi_controllers"
end
