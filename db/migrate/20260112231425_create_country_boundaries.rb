class CreateCountryBoundaries < ActiveRecord::Migration[8.1]
  def change
    create_table :country_boundaries do |t|
      t.string :code, null: false
      t.string :name
      t.st_polygon :geometry, srid: 4326, geographic: true

      t.timestamps
    end
    add_index :country_boundaries, :code, unique: true
    add_index :country_boundaries, :geometry, using: :gist
  end
end
