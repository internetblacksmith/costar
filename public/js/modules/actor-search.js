// Refactored Actor search and selection functionality
class ActorSearch {
    constructor() {
        try {
            this.eventManager = new EventManager();
            this.setupEventListeners();
            this.initializeFields();
        } catch (error) {
            console.error('Error initializing ActorSearch:', error);
            if (window.ErrorReporter) {
                ErrorReporter.report(error, { phase: 'actor_search_init' });
            }
        }
    }

    setupEventListeners() {
        // HTMX event handlers
        EventManager.onHTMXBeforeRequest('#compareBtn', (event) => this.handleCompareStart(event));
        EventManager.onHTMXAfterRequest('#compareBtn', (event) => this.handleCompareComplete(event));
        EventManager.onHTMXResponseError('#compareBtn', (event) => this.handleCompareError(event));

        // Input field handlers
        EventManager.delegate(document.body, 'input', '#actor1, #actor2', (event) => {
            this.handleSearchInput(event.target);
        });
    }

    initializeFields() {
         // Don't clear fields if loading from share link
         if (!FieldManager.isShareLink()) {
             FieldManager.clearAllFields();
         }
     }

    handleCompareStart(event) {
         // Show results section
         DOMManager.addClass('results', 'show');
         
         // Show loading indicator
         DOMManager.setHTML('timeline', DOMManager.createLoadingHTML());
         
         // Initialize MDC components
         DOMManager.initializeMDC(DOMManager.getElement('timeline'));
         
         // Disable button
         event.target.disabled = true;
     }

    handleCompareComplete(event) {
         event.target.disabled = false;
         
         // Track successful comparison
         if (event.detail.successful) {
             const actor1 = FieldManager.getActorValues('actor1');
             const actor2 = FieldManager.getActorValues('actor2');
             AnalyticsTracker.trackComparisonCompleted(actor1.name, actor2.name);
         }
     }

    handleCompareError(event) {
         event.target.disabled = false;
     }

    handleSearchInput(inputElement) {
        const field = inputElement.id;
        
        // Clear suggestions if input is empty
        if (inputElement.value.trim() === '') {
            FieldManager.clearSuggestions(field);
        }
    }

    selectActor(actorId, actorName, field) {
        try {
            // Clear current input
            FieldManager.clearInputField(field);
            
            // Set all actor values
            FieldManager.setActorValues(field, actorId, actorName);
            
            // Clear suggestions
            FieldManager.clearSuggestions(field);
            
            // Create and display chip
            this.displayActorChip(field, actorId, actorName);
            
            // Show notification
            if (window.snackbarModule) {
                window.snackbarModule.show(`${actorName} selected!`);
            }
            
            // Track selection
            AnalyticsTracker.trackActorSelection(actorName, field);
            
        } catch (error) {
            console.error('Error selecting actor:', error);
            if (window.ErrorReporter) {
                ErrorReporter.report(error, { 
                    phase: 'actor_selection',
                    actorId: actorId,
                    field: field
                });
            }
        }
    }

    removeActor(field) {
        try {
            // Clear all actor values
            FieldManager.clearActorValues(field);
            
            // Restore input field
            this.displayInputField(field);
            
            // Clear the timeline/filmographies when an actor is deselected
            DOMManager.setHTML('timeline', '');
            
            // Hide the results section
            DOMManager.removeClass('results', 'show');
            
            // Show notification
            if (window.snackbarModule) {
                window.snackbarModule.show('Actor removed');
            }
            
        } catch (error) {
            console.error('Error removing actor:', error);
            if (window.ErrorReporter) {
                ErrorReporter.report(error, { phase: 'remove_actor', field: field });
            }
        }
    }

    displayActorChip(field, actorId, actorName) {
        const container = DOMManager.getElement(`${field}Container`);
        if (!container) return;
        
        const chipHTML = DOMManager.createChipHTML(field, actorName);
        const hiddenInputsHTML = DOMManager.createHiddenInputs(field, actorId, actorName);
        
        container.innerHTML = chipHTML + hiddenInputsHTML;
        DOMManager.initializeMDC(container);
    }

    displayInputField(field) {
        const container = DOMManager.getElement(`${field}Container`);
        if (!container) return;
        
        const { labelText, suggestionId } = FieldManager.getFieldConfig(field);
        const textFieldHTML = DOMManager.createTextFieldHTML(field, labelText, suggestionId);
        const suggestionsHTML = `<div class="suggestions" id="suggestions${suggestionId}"></div>`;
        const hiddenInputsHTML = DOMManager.createHiddenInputs(field);
        
        container.innerHTML = textFieldHTML + suggestionsHTML + hiddenInputsHTML;
        DOMManager.initializeMDC(container);
        
        // Give HTMX a moment to fully process the new elements
        if (typeof htmx !== 'undefined') {
            // Force HTMX to process immediately
            setTimeout(() => {
                const input = DOMManager.getElement(field);
                if (input) {
                    input.focus();
                }
            }, 50);
        }
    }

    trackComparison() {
        const actor1 = FieldManager.getActorValues('actor1');
        const actor2 = FieldManager.getActorValues('actor2');
        AnalyticsTracker.trackComparisonStarted(actor1.name, actor2.name);
    }

    // Backward compatibility method
    clearInputFields() {
        this.initializeFields();
    }
}

// Export for use in other modules
window.ActorSearch = ActorSearch;