// Analytics tracking functionality
class AnalyticsTracker {
    static isAvailable() {
        return typeof posthog !== 'undefined';
    }

    static track(eventName, properties = {}) {
        if (this.isAvailable()) {
            posthog.capture(eventName, properties);
        }
    }

    static trackActorSelection(actorName, field) {
        this.track('actor_selected', {
            actor_name: actorName,
            field: field
        });
    }

    static trackComparisonStarted(actor1Name, actor2Name) {
        this.track('comparison_started', {
            actor1: actor1Name,
            actor2: actor2Name
        });
    }

    static trackComparisonCompleted(actor1Name, actor2Name) {
        this.track('comparison_completed', {
            actor1: actor1Name,
            actor2: actor2Name
        });
    }

    static trackError(errorType, details = {}) {
        this.track('error_occurred', {
            error_type: errorType,
            ...details
        });
    }
}

// Export for use in other modules
window.AnalyticsTracker = AnalyticsTracker;