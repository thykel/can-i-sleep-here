class CreateForestAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :forest_areas do |t|
      t.string :osm_id
      t.string :name
      t.string :forest_type # 'forest' or 'wood'
      t.multi_polygon :geometry, srid: 4326, geographic: true

      t.timestamps
    end

    add_index :forest_areas, :osm_id, unique: true
    add_index :forest_areas, :geometry, using: :gist
  end
end
