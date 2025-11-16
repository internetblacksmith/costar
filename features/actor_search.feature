Feature: Actor Search
  As a user
  I want to search for actors
  So that I can find and select actors to compare

  Background:
    Given I am on the home page

   @vcr
   Scenario: Successful actor search with browser headers
    When I search for "Tom Hanks" in the first actor field
    Then I should see search suggestions
    And the suggestions should include "Tom Hanks"
    And the response should have status code 200
    And no rate limiting errors should occur

  @vcr
  Scenario: Search with special characters
    When I search for "José García" in the first actor field
    Then I should see search suggestions
    And the response should have status code 200

  @vcr
  Scenario: Empty search returns no results
    When I search for "" in the first actor field
    Then I should not see search suggestions
    And the response should have status code 200

  @vcr
  Scenario: Search with multiple actors
    When I search for "Chris" in the first actor field
    Then I should see search suggestions
    And the suggestions should include multiple actors containing "Chris"
    And the response should have status code 200

  @vcr
  Scenario: Rapid successive searches (rate limit test)
    When I rapidly search for the following terms:
      | search_term |
      | Tom         |
      | Tom H       |
      | Tom Ha      |
      | Tom Han     |
      | Tom Hank    |
    Then all searches should complete successfully
    And no rate limiting errors should occur

  @api_error
  Scenario: Search handles API errors gracefully
    Given the TMDB API is returning errors
    When I search for "Tom Hanks" in the first actor field
    Then I should see an error message
    But the application should not crash