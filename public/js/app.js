// Main application initialization
class App {
    constructor() {
        this.actorSearch = null;
        this.scrollToTop = null;
        this.mobileKeyboard = null;
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
             // Initialize modules
             this.actorSearch = new ActorSearch();
             this.scrollToTop = new ScrollToTop();
             this.mobileKeyboard = new MobileKeyboard();
             
             // Make actor search available globally for onclick handlers
             window.actorSearch = this.actorSearch;
         } catch (error) {
             console.error('Error initializing app:', error);
             // Report initialization errors
             if (window.ErrorReporter) {
                 ErrorReporter.report(error, { phase: 'initialization' });
             }
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
