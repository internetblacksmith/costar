# frozen_string_literal: true

FactoryBot.define do
  factory :movie do
    skip_create

    id { Faker::Number.unique.number(digits: 6) }
    title { Faker::Movie.title }
    release_date { Faker::Date.between(from: "1990-01-01", to: Date.current).strftime("%Y-%m-%d") }
    vote_average { Faker::Number.decimal(l_digits: 1, r_digits: 1) }
    overview { Faker::Lorem.paragraph(sentence_count: 3) }
    poster_path { "/#{Faker::Alphanumeric.alpha(number: 10)}.jpg" }
    backdrop_path { "/#{Faker::Alphanumeric.alpha(number: 10)}.jpg" }
    character { Faker::Name.name }

    trait :inception do
      id { 27_205 }
      title { "Inception" }
      release_date { "2010-07-16" }
      vote_average { 8.4 }
      character { "Dom Cobb" }
      poster_path { "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg" }
    end

    trait :forrest_gump do
      id { 13 }
      title { "Forrest Gump" }
      release_date { "1994-07-06" }
      vote_average { 8.5 }
      character { "Forrest Gump" }
      poster_path { "/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg" }
    end

    trait :catch_me_if_you_can do
      id { 640 }
      title { "Catch Me If You Can" }
      release_date { "2002-12-25" }
      vote_average { 8.1 }
      poster_path { "/ctjEj2xM32OvBXCq8zAdK3ZrsAj.jpg" }
    end
  end
end
