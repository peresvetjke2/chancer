See PROJECT.md for project description.

## Stack
Ruby on Rails 8, PostgreSQL, RSpec

## Key commands
- `bin/setup` — bootstrap
- `bin/rails s` — run server
- `bundle exec rspec` — run tests
- `bin/rails db:migrate` — migrate

## Conventions
- Standard Rails MVC, no service objects yet
- RSpec for tests, FactoryBot for fixtures
- No new gems without explicit request

## Constraints
- Don't touch existing migrations
- Don't implement auth