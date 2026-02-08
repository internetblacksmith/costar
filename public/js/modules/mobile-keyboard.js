// Mobile keyboard handling - scrolls input fields into view when focused
class MobileKeyboard {
    constructor() {
        this.MOBILE_BREAKPOINT = 768;
        this.KEYBOARD_DELAY = 350; // Time for keyboard to appear
        this.setupEventListeners();
    }

    isMobile() {
        return window.innerWidth <= this.MOBILE_BREAKPOINT;
    }

    setupEventListeners() {
        // Use event delegation for dynamically created inputs
        EventManager.delegate(document.body, "focus", "#actor1, #actor2", (event) => {
            this.handleInputFocus(event.target);
        });

        // Also handle the initial inputs on page load
        document.querySelectorAll("#actor1, #actor2").forEach(input => {
            input.addEventListener("focus", () => this.handleInputFocus(input));
        });
    }

    handleInputFocus(inputElement) {
        if (!this.isMobile()) return;

        // Wait for the keyboard to appear before scrolling
        setTimeout(() => {
            this.scrollInputToTop(inputElement);
        }, this.KEYBOARD_DELAY);
    }

    scrollInputToTop(inputElement) {
        if (!inputElement) return;

        // Get the search field container (parent of the input)
        const container = inputElement.closest(".search-field-container");
        const targetElement = container || inputElement;

        // Calculate scroll position to put input near top of viewport
        // Leave some space at the top for context (header visibility)
        const headerOffset = 80;
        const elementRect = targetElement.getBoundingClientRect();
        const absoluteElementTop = elementRect.top + window.pageYOffset;
        const scrollPosition = absoluteElementTop - headerOffset;

        window.scrollTo({
            top: scrollPosition,
            behavior: "smooth"
        });
    }
}

// Export for use in other modules
window.MobileKeyboard = MobileKeyboard;
