class Player < ApplicationRecord
  belongs_to :team
  has_many :player_stats

  validates :name, presence: true
  validates :pandascore_id, uniqueness: true, allow_nil: true
end
