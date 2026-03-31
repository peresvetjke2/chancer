class Match < ApplicationRecord
  belongs_to :team1, class_name: "Team"
  belongs_to :team2, class_name: "Team"
  belongs_to :winner, class_name: "Team", optional: true
  has_many :map_results
  has_many :player_stats

  validates :played_at, presence: true
end
