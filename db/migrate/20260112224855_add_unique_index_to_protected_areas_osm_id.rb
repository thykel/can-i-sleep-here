class AddUniqueIndexToProtectedAreasOsmId < ActiveRecord::Migration[8.1]
  def change
    add_index :protected_areas, :osm_id, unique: true
  end
end
