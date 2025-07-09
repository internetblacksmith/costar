// Snackbar notification functionality
class SnackbarModule {
    constructor() {
        this.snackbar = null;
        this.init();
    }

    init() {
        // Initialize snackbar when MDC is ready
        if (typeof mdc !== 'undefined') {
            const snackbarElement = document.getElementById('snackbar');
            if (snackbarElement && snackbarElement.MDCSnackbar) {
                this.snackbar = snackbarElement.MDCSnackbar;
            }
        }
    }

    show(message, action = null) {
        if (!this.snackbar) {
            this.init(); // Try to initialize again
        }

        const messageElement = document.getElementById('snackbarMessage');
        const actionButton = document.getElementById('snackbarAction');
        
        if (messageElement) {
            messageElement.textContent = message;
        }
        
        if (actionButton) {
            if (action) {
                actionButton.style.display = 'inline-block';
                actionButton.onclick = action;
            } else {
                actionButton.style.display = 'none';
            }
        }
        
        if (this.snackbar) {
            this.snackbar.open();
        } else {
            // Fallback to console if snackbar is not available
            console.log('Notification:', message);
        }
    }
}

// Export for global use
window.snackbarModule = new SnackbarModule();