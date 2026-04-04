class Team < ApplicationRecord
  has_many :players

  validates :name, presence: true
  validates :hltv_id, uniqueness: true, allow_nil: true
end
