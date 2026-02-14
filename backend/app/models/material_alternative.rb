class MaterialAlternative < ApplicationRecord
  belongs_to :material
  belongs_to :alternative_material, class_name: 'Material'
end
