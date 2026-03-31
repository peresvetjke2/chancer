class MapResult < ApplicationRecord
  belongs_to :match

  validates :map_name, presence: true
end
