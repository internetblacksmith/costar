Feature: Actor Reselection
  As a user
  I want to be able to change my actor selection
  So that I can correct mistakes or explore different comparisons

  Background:
    Given I am on the home page

  @vcr @javascript
  Scenario: Changing actor selection after initial choice
    # First selection using existing steps
    When I select "Tom Hanks" as the first actor
    Then the "actor1" field should contain "Tom Hanks"
    And the "actor1_id" hidden field should have a value
    
    # Clear selection
    When I click the clear button for "actor1"
    Then the "actor1" field should be empty
    And the "actor1_id" hidden field should be empty
    
    # Second selection using existing steps
    When I select "Brad Pitt" as the first actor
    Then the "actor1" field should contain "Brad Pitt"
    And the "actor1_id" hidden field should have a value

  @javascript
  Scenario: Selecting different actors in both fields
    # First actor
    When I fill in "actor1" with "Tom"
    And I wait for suggestions to appear
    And I select "Tom Cruise" from the suggestions for "actor1"
    Then the "actor1" field should contain "Tom Cruise"
    
    # Second actor
    When I fill in "actor2" with "Brad"
    And I wait for suggestions to appear
    And I select "Brad Pitt" from the suggestions for "actor2"
    Then the "actor2" field should contain "Brad Pitt"
    
    # Change first actor
    When I click the clear button for "actor1"
    And I fill in "actor1" with "Leo"
    And I wait for suggestions to appear
    And I select "Leonardo DiCaprio" from the suggestions for "actor1"
    Then the "actor1" field should contain "Leonardo DiCaprio"
    And the "actor2" field should contain "Brad Pitt"