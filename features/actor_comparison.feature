Feature: Actor Comparison
  As a user
  I want to compare two actors' filmographies
  So that I can see which movies they have in common

  Background:
    Given I am on the home page

   @vcr @javascript
   Scenario: Compare two actors with common movies
    When I select "Tom Hanks" as the first actor
    And I select "Meg Ryan" as the second actor
    And I click "Explore Filmographies Together"
    Then I should see the timeline comparison
    And I should see movies for both actors
    And I should see their common movies highlighted
    And the response should have status code 200

   @vcr @javascript
   Scenario: Compare two actors with no common movies
    When I select "Tom Hanks" as the first actor
    And I select "Jackie Chan" as the second actor
    And I click "Explore Filmographies Together"
    Then I should see the timeline comparison
    And I should see movies for both actors
    But I should not see any common movies highlighted

  @vcr
  Scenario: Compare using actor IDs directly
    When I visit the comparison URL for actors "31" and "5344"
    Then I should see the timeline comparison
    And the timeline should load successfully
    And no rate limiting errors should occur

   @vcr @javascript
   Scenario: Invalid actor comparison
    When I visit the comparison URL for actors "99999" and "99998"
    Then I should see an error message
    And the response should have status code 200

   @vcr @javascript
   Scenario: Missing actor parameter
    When I select "Tom Hanks" as the first actor
    And I click "Explore Filmographies Together" without selecting a second actor
    Then I should see an error message
    And I should remain on the home page

   @vcr @javascript
   Scenario: Full user flow with browser simulation
    # This tests the complete flow as a real user would experience it
    When I select "Tom Hanks" as the first actor
    And I select "Meg Ryan" as the second actor
    And I click "Explore Filmographies Together"
    Then I should see the timeline comparison
    And I should see "Tom Hanks"
    And I should see "Meg Ryan"
    And the timeline should show movies from both actors