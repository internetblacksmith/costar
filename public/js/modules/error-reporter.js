// Error reporting functionality for frontend
class ErrorReporter {
    constructor() {
        this.errorCount = 0;
        this.maxErrorsPerSession = 10; // Prevent error spam
        this.reportedErrors = new Set(); // Track unique errors
        this.init();
    }

    init() {
        // Set up global error handler
        window.addEventListener('error', (event) => {
            this.handleError(event.error || event, {
                message: event.message,
                filename: event.filename,
                lineno: event.lineno,
                colno: event.colno
            });
        });

        // Set up unhandled promise rejection handler
        window.addEventListener('unhandledrejection', (event) => {
            this.handleError(event.reason, {
                type: 'unhandledRejection',
                promise: event.promise
            });
        });

        // HTMX error handling - ensure document.body exists
        if (typeof htmx !== 'undefined' && document.body) {
            document.body.addEventListener('htmx:responseError', (event) => {
                this.handleHTMXError(event);
            });

            document.body.addEventListener('htmx:sendError', (event) => {
                this.handleHTMXError(event);
            });

            document.body.addEventListener('htmx:sseError', (event) => {
                this.handleHTMXError(event);
            });

            document.body.addEventListener('htmx:oobError', (event) => {
                this.handleHTMXError(event);
            });
        }
    }

    handleError(error, context = {}) {
        // Prevent error spam
        if (this.errorCount >= this.maxErrorsPerSession) {
            return;
        }

        // Create error signature for deduplication
        const errorSignature = this.createErrorSignature(error, context);
        if (this.reportedErrors.has(errorSignature)) {
            return;
        }

        this.reportedErrors.add(errorSignature);
        this.errorCount++;

        // Log to console for debugging
        console.error('Error caught by ErrorReporter:', error, context);

        // Report to Sentry if available
        if (typeof Sentry !== 'undefined' && Sentry.captureException) {
            Sentry.captureException(error, {
                contexts: {
                    errorReporter: context
                }
            });
        }

        // Show user-friendly notification
        this.showUserNotification(error, context);
    }

    handleHTMXError(event) {
        const context = {
            type: 'htmx',
            eventType: event.type,
            target: event.detail.target,
            xhr: event.detail.xhr
        };

        let errorMessage = 'Network request failed';
        if (event.detail.xhr) {
            const status = event.detail.xhr.status;
            if (status === 429) {
                errorMessage = 'Too many requests. Please slow down and try again.';
            } else if (status >= 500) {
                errorMessage = 'Server error. Please try again later.';
            } else if (status === 404) {
                errorMessage = 'Resource not found.';
            } else if (status === 0) {
                errorMessage = 'Network connection error. Please check your internet connection.';
            }
        }

        this.handleError(new Error(errorMessage), context);
    }

    createErrorSignature(error, context) {
        const message = error?.message || String(error);
        const stack = error?.stack || '';
        const filename = context.filename || '';
        const lineno = context.lineno || '';
        
        return `${message}-${stack.substring(0, 200)}-${filename}-${lineno}`;
    }

    showUserNotification(error, context) {
        let userMessage = 'An error occurred. Please try again.';
        
        // Customize message based on error type
        if (context.type === 'unhandledRejection') {
            userMessage = 'An unexpected error occurred. Please refresh the page if issues persist.';
        } else if (context.type === 'htmx') {
            // Use the error message directly for HTMX errors
            userMessage = error.message;
        } else if (error?.message?.includes('Network')) {
            userMessage = 'Network error. Please check your connection and try again.';
        } else if (error?.message?.includes('Script error')) {
            // Generic script errors often come from extensions or third-party scripts
            return; // Don't show notification for these
        }

        // Show notification using snackbar
        if (window.snackbarModule && window.snackbarModule.show) {
            window.snackbarModule.show(userMessage);
        } else {
            // Fallback to alert if snackbar not available
            console.warn('Snackbar not available, using console:', userMessage);
        }
    }

    // Manual error reporting method
    static report(error, context = {}) {
        if (!window.errorReporter) {
            console.error('ErrorReporter not initialized:', error);
            return;
        }
        
        window.errorReporter.handleError(error, {
            ...context,
            manual: true
        });
    }

    // Method to test error handling
    static test() {
        throw new Error('Test error from ErrorReporter');
    }
}

// Initialize error reporter globally
window.errorReporter = new ErrorReporter();

// Export for modules
window.ErrorReporter = ErrorReporter;