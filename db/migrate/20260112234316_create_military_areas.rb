class CreateMilitaryAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :military_areas do |t|
      t.string :name, null: false
      t.string :osm_id
      t.st_polygon :geometry, srid: 4326, geographic: true

      t.timestamps
    end

    add_index :military_areas, :osm_id, unique: true
    add_index :military_areas, :geometry, using: :gist
  end
end
