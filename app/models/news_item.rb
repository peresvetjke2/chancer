class NewsItem < ApplicationRecord
  validates :source, presence: true
end
