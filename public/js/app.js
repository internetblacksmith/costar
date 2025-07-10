// Main application initialization
class App {
    constructor() {
        this.actorSearch = null;
        this.scrollToTop = null;
        this.init();
    }

    init() {
        // Wait for DOM to be ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.initializeApp());
        } else {
            this.initializeApp();
        }
    }

    initializeApp() {
        try {
            // Auto-initialize all MDC components
            if (typeof mdc !== 'undefined') {
                mdc.autoInit();
            }
            
            // Initialize modules
            this.actorSearch = new ActorSearch();
            this.scrollToTop = new ScrollToTop();
            
            // Make actor search available globally for onclick handlers
            window.actorSearch = this.actorSearch;
            
            console.log('ActorSync app initialized successfully');
        } catch (error) {
            console.error('Error initializing app:', error);
        }
    }
}

// Global functions for backward compatibility with ERB templates
function selectActor(actorId, actorName, field) {
    if (window.actorSearch) {
        window.actorSearch.selectActor(actorId, actorName, field);
    }
}

function trackComparison() {
    if (window.actorSearch) {
        window.actorSearch.trackComparison();
    }
}

// Initialize the application
new App();