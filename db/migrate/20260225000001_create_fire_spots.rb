class CreateFireSpots < ActiveRecord::Migration[8.1]
  def change
    create_table :fire_spots do |t|
      t.string :osm_id
      t.string :name
      t.float :lat, null: false
      t.float :lng, null: false
      t.st_geography :geometry

      t.timestamps
    end

    add_index :fire_spots, :osm_id, unique: true
    add_index :fire_spots, :geometry, using: :gist
  end
end
