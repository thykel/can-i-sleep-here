class CreateProtectedAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :protected_areas do |t|
      t.string :name, null: false
      t.string :protect_class
      t.string :protection_title
      t.string :country, default: "CZ"
      t.string :osm_id
      t.multi_polygon :geometry, srid: 4326, geographic: true

      t.timestamps
    end

    add_index :protected_areas, :geometry, using: :gist
    add_index :protected_areas, :protect_class
    add_index :protected_areas, :country
  end
end
