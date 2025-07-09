// Scroll to top functionality
class ScrollToTop {
    constructor() {
        this.fab = null;
        this.init();
    }

    init() {
        this.fab = document.getElementById('scrollToTop');
        if (this.fab) {
            this.setupEventListeners();
        }
    }

    setupEventListeners() {
        // Show/hide FAB based on scroll position
        window.addEventListener('scroll', () => {
            if (window.scrollY > 300) {
                this.fab.style.display = 'block';
            } else {
                this.fab.style.display = 'none';
            }
        });
        
        // Handle click to scroll to top
        this.fab.addEventListener('click', () => {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        });
    }
}

// Export for use in main app
window.ScrollToTop = ScrollToTop;