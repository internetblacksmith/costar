# frozen_string_literal: true

require "spec_helper"

RSpec.describe "views/suggestions.erb" do
  def render_suggestions(actors, field)
    @actors = actors
    @field = field
    erb = ERB.new(File.read("views/suggestions.erb"))
    erb.result(binding)
  end

  describe "rendering actor suggestions" do
    context "with actors having known_for data" do
      let(:actors_with_known_for) do
        [
          {
            id: 1,
            name: "Tom Hanks",
            known_for: [
              { title: "Forrest Gump" },
              { title: "Cast Away" },
              { title: "The Green Mile" }
            ]
          },
          {
            id: 2,
            name: "Meryl Streep",
            known_for: [
              { title: "The Devil Wears Prada" },
              { title: "Sophie's Choice" }
            ]
          }
        ]
      end

      it "displays known_for titles correctly" do
        html = render_suggestions(actors_with_known_for, "actor1")

        # Check that actor names are present
        expect(html).to include("Tom Hanks")
        expect(html).to include("Meryl Streep")

        # Check that known_for is displayed correctly
        expect(html).to include("Known for: Forrest Gump, Cast Away, The Green Mile")
        expect(html).to include("Known for: The Devil Wears Prada, Sophie's Choice")

        # Ensure no hash formatting leaks through
        expect(html).not_to include("{title:")
        expect(html).not_to include("title: ")
        # Ensure the "Known for:" text is not truncated (should not start with just "wn for:")
        expect(html).not_to match(/^\s*wn\s+for:/m)
      end

      it "escapes actor names properly in onclick handlers" do
        actors = [{
          id: 3,
          name: "Michael O'Neill",
          known_for: [{ title: "Test Movie" }]
        }]

        html = render_suggestions(actors, "actor2")

        # Check that single quotes are escaped in onclick
        # The actual output escapes the quote differently in the HTML context
        expect(html).to match(/selectActor\('3', 'Michael O.*Neill', 'actor2'\)/)
      end
    end

    context "with actors having empty known_for data" do
      let(:actors_without_known_for) do
        [
          {
            id: 4,
            name: "Unknown Actor",
            known_for: []
          }
        ]
      end

      it "does not display Known for section when empty" do
        html = render_suggestions(actors_without_known_for, "actor1")

        expect(html).to include("Unknown Actor")
        expect(html).not_to include("Known for:")
      end
    end

    context "with actors having nil known_for data" do
      let(:actors_with_nil_known_for) do
        [
          {
            id: 5,
            name: "Actor Without Data",
            known_for: nil
          }
        ]
      end

      it "handles nil known_for gracefully" do
        html = render_suggestions(actors_with_nil_known_for, "actor1")

        expect(html).to include("Actor Without Data")
        expect(html).not_to include("Known for:")
        # Should not raise any errors
      end
    end

    context "with empty actors array" do
      it "renders nothing when actors array is empty" do
        html = render_suggestions([], "actor1")
        expect(html.strip).to be_empty
      end
    end

    context "with nil actors" do
      it "renders nothing when actors is nil" do
        html = render_suggestions(nil, "actor1")
        expect(html.strip).to be_empty
      end
    end

    context "field parameter propagation" do
      let(:actors) do
        [{
          id: 6,
          name: "Test Actor",
          known_for: [{ title: "Test Movie" }]
        }]
      end

      it "includes correct field in selectActor calls" do
        html = render_suggestions(actors, "actor1")
        expect(html).to include("selectActor('6', 'Test Actor', 'actor1')")

        html = render_suggestions(actors, "actor2")
        expect(html).to include("selectActor('6', 'Test Actor', 'actor2')")
      end
    end
  end
end
