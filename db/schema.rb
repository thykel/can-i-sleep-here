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

ActiveRecord::Schema[8.1].define(version: 2026_01_12_234316) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "country_boundaries", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.st_polygon "geometry", geographic: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_country_boundaries_on_code", unique: true
    t.index ["geometry"], name: "index_country_boundaries_on_geometry", using: :gist
  end

  create_table "forest_areas", force: :cascade do |t|
    t.string "osm_id"
    t.string "name"
    t.string "forest_type"
    t.st_geography "geometry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["geometry"], name: "index_forest_areas_on_geometry", using: :gist
    t.index ["osm_id"], name: "index_forest_areas_on_osm_id", unique: true
  end

  create_table "military_areas", force: :cascade do |t|
    t.string "osm_id"
    t.string "name", null: false
    t.st_polygon "geometry", geographic: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["geometry"], name: "index_military_areas_on_geometry", using: :gist
    t.index ["osm_id"], name: "index_military_areas_on_osm_id", unique: true
  end

  create_table "protected_areas", force: :cascade do |t|
    t.string "name", null: false
    t.string "protect_class"
    t.string "protection_title"
    t.string "country", default: "CZ"
    t.string "osm_id"
    t.st_geography "geometry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_protected_areas_on_country"
    t.index ["geometry"], name: "index_protected_areas_on_geometry", using: :gist
    t.index ["osm_id"], name: "index_protected_areas_on_osm_id", unique: true
    t.index ["protect_class"], name: "index_protected_areas_on_protect_class"
  end
end
