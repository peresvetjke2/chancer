class Player < ApplicationRecord
  belongs_to :team
  has_many :player_stats

  validates :name, presence: true
end
