# frozen_string_literal: true

FactoryBot.define do
  factory :actor do
    skip_create

    id { Faker::Number.unique.number(digits: 6) }
    name { Faker::Name.name }
    popularity { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    profile_path { "/#{Faker::Alphanumeric.alpha(number: 10)}.jpg" }

    trait :leonardo_dicaprio do
      id { 6193 }
      name { "Leonardo DiCaprio" }
      popularity { 15.73 }
      profile_path { "/wo2hJpn04vbtmh0B9utCFdsQhxM.jpg" }
    end

    trait :tom_hanks do
      id { 31 }
      name { "Tom Hanks" }
      popularity { 12.45 }
      profile_path { "/xndWFsBlClOJFRdhSt4NBwiPq2o.jpg" }
    end
  end
end
