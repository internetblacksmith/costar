// Event handling and delegation
class EventManager {
    constructor() {
        this.listeners = new Map();
    }

    // Add event listener with automatic cleanup tracking
    addEventListener(element, event, handler, options) {
        if (!element) return;
        
        element.addEventListener(event, handler, options);
        
        // Track for cleanup
        const key = `${element.id || 'document'}-${event}`;
        if (!this.listeners.has(key)) {
            this.listeners.set(key, []);
        }
        this.listeners.get(key).push({ element, handler, options });
    }

    // Remove all tracked event listeners
    removeAllEventListeners() {
        this.listeners.forEach((handlers, key) => {
            handlers.forEach(({ element, event, handler, options }) => {
                element.removeEventListener(event, handler, options);
            });
        });
        this.listeners.clear();
    }

    // Set up delegated event listener
    static delegate(parentSelector, eventType, childSelector, handler) {
        const parent = typeof parentSelector === 'string' 
            ? document.querySelector(parentSelector) 
            : parentSelector;
            
        if (!parent) return;

        parent.addEventListener(eventType, (event) => {
            const targetElement = event.target.closest(childSelector);
            if (targetElement && parent.contains(targetElement)) {
                handler.call(targetElement, event);
            }
        });
    }

    // HTMX event helpers
    static onHTMXBeforeRequest(selector, handler) {
        document.body.addEventListener('htmx:beforeRequest', (event) => {
            if (event.target.matches(selector)) {
                handler(event);
            }
        });
    }

    static onHTMXAfterRequest(selector, handler) {
        document.body.addEventListener('htmx:afterRequest', (event) => {
            if (event.target.matches(selector)) {
                handler(event);
            }
        });
    }

    static onHTMXResponseError(selector, handler) {
        document.body.addEventListener('htmx:responseError', (event) => {
            if (event.target.matches(selector)) {
                handler(event);
            }
        });
    }

    // Debounce helper for input events
    static debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
}

// Export for use in other modules
window.EventManager = EventManager;