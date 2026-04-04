class MapResult < ApplicationRecord
  belongs_to :match
  belongs_to :winner_team, class_name: "Team", optional: true

  validates :map_name, presence: true
end
