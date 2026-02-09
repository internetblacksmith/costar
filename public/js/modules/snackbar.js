// Toast notification functionality (replaces MDC Snackbar)
class SnackbarModule {
    constructor() {
        this.toastElement = null;
        this.hideTimeout = null;
        this.init();
    }

    init() {
        this.toastElement = document.getElementById('snackbar');
    }

    show(message, action = null) {
        if (!this.toastElement) {
            this.init();
        }
        if (!this.toastElement) return;

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
        
        // Show toast
        this.toastElement.classList.add('toast--open');
        
        // Clear any existing timeout
        if (this.hideTimeout) {
            clearTimeout(this.hideTimeout);
        }
        
        // Auto-hide after 3 seconds
        this.hideTimeout = setTimeout(() => {
            this.toastElement.classList.remove('toast--open');
        }, 3000);
    }
}

// Export for global use
window.snackbarModule = new SnackbarModule();
