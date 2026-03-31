class Team < ApplicationRecord
  has_many :players

  validates :name, presence: true
  validates :hltv_id, presence: true, uniqueness: true
end
