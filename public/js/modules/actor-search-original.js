// Actor search and selection functionality
class ActorSearch {
    constructor() {
        try {
            this.setupEventListeners();
            this.clearInputFields();
        } catch (error) {
            console.error('Error initializing ActorSearch:', error);
            if (window.ErrorReporter) {
                ErrorReporter.report(error, { phase: 'actor_search_init' });
            }
        }
    }

    setupEventListeners() {
        // HTMX event handlers for loading and button state
        document.body.addEventListener('htmx:beforeRequest', (event) => {
            if (event.target.id === 'compareBtn') {
                this.handleCompareStart(event);
            }
        });

        document.body.addEventListener('htmx:afterRequest', (event) => {
            if (event.target.id === 'compareBtn') {
                this.handleCompareComplete(event);
            }
        });

        document.body.addEventListener('htmx:responseError', (event) => {
            if (event.target.id === 'compareBtn') {
                this.handleCompareError(event);
            }
        });

        // Handle input clearing for search fields
        document.body.addEventListener('input', (event) => {
            if (event.target.matches('#actor1, #actor2')) {
                this.handleSearchInput(event.target);
            }
        });
    }

    handleCompareStart(event) {
         const results = document.getElementById('results');
        const timeline = document.getElementById('timeline');
        
        // Show results section and inject loading content immediately
        results.classList.add('show');
        timeline.innerHTML = `
            <div class="loading show">
                <p>Loading filmographies...</p>
                <div class="mdc-linear-progress mdc-linear-progress--indeterminate" data-mdc-auto-init="MDCLinearProgress">
                    <div class="mdc-linear-progress__buffer">
                        <div class="mdc-linear-progress__buffer-bar"></div>
                        <div class="mdc-linear-progress__buffer-dots"></div>
                    </div>
                    <div class="mdc-linear-progress__bar mdc-linear-progress__primary-bar">
                        <span class="mdc-linear-progress__bar-inner"></span>
                    </div>
                    <div class="mdc-linear-progress__bar mdc-linear-progress__secondary-bar">
                        <span class="mdc-linear-progress__bar-inner"></span>
                    </div>
                </div>
            </div>
        `;
        
        // Initialize the progress bar
        if (typeof mdc !== 'undefined') {
            mdc.autoInit(timeline);
        }
        
        event.target.disabled = true;
    }

    handleCompareComplete(event) {
         event.target.disabled = false;
        
        // Track successful comparison only if request was successful
        if (event.detail.successful && typeof posthog !== 'undefined') {
            const actor1Name = document.getElementById('actor1_name').value;
            const actor2Name = document.getElementById('actor2_name').value;
            posthog.capture('comparison_completed', {
                actor1: actor1Name,
                actor2: actor2Name
            });
        }
    }

    handleCompareError(event) {
         event.target.disabled = false;
    }

    handleSearchInput(inputElement) {
        const field = inputElement.id;
        const suggestionId = field === 'actor1' ? '1' : '2';
        const suggestionsContainer = document.getElementById(`suggestions${suggestionId}`);
        
        // Clear suggestions if input is empty
        if (inputElement.value.trim() === '') {
            if (suggestionsContainer) {
                suggestionsContainer.innerHTML = '';
            }
        }
    }

    selectActor(actorId, actorName, field) {
        try {
            const suggestionId = field === 'actor1' ? '1' : '2';
        
        // Clear the current input field value first
        const inputField = document.getElementById(field);
        if (inputField) {
            inputField.value = '';
        }
        
        // Set hidden field values
        document.getElementById(field + '_id').value = actorId;
        document.getElementById(field + '_name').value = actorName;
        document.getElementById('suggestions' + suggestionId).innerHTML = '';
        
        // Also set backup fields
        const idBackup = document.getElementById(field + '_id_backup');
        const nameBackup = document.getElementById(field + '_name_backup');
        if (idBackup) idBackup.value = actorId;
        if (nameBackup) nameBackup.value = actorName;
        
        // Replace the input field with a chip but keep hidden fields
        const container = document.getElementById(field + 'Container');
        container.innerHTML = `
            <div class="mdc-chip selected-actor-chip" data-field="${field}" data-mdc-auto-init="MDCChip">
                <div class="mdc-chip__ripple"></div>
                <span class="mdc-chip__primary-action">
                    <span class="mdc-chip__text">${actorName}</span>
                </span>
                <span class="mdc-chip__trailing-icon material-icons" onclick="window.actorSearch.removeActor('${field}')" tabindex="0" role="button">cancel</span>
            </div>
            <input type="hidden" id="${field}_id" name="${field}_id" value="${actorId}">
            <input type="hidden" id="${field}_name" name="${field}_name" value="${actorName}">
        `;
        
        // Initialize the new chip
        if (typeof mdc !== 'undefined') {
            mdc.autoInit(container);
        }
        
        // Show success snackbar
        if (window.snackbarModule) {
            window.snackbarModule.show(`${actorName} selected!`);
        }
        
        // Track actor selection
        if (typeof posthog !== 'undefined') {
            posthog.capture('actor_selected', {
                actor_name: actorName,
                field: field
            });
        }
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
            // Clear the hidden fields
            document.getElementById(field + '_id').value = '';
        document.getElementById(field + '_name').value = '';
        
        // Clear backup fields
        const idBackup = document.getElementById(field + '_id_backup');
        const nameBackup = document.getElementById(field + '_name_backup');
        if (idBackup) idBackup.value = '';
        if (nameBackup) nameBackup.value = '';
        
        // Restore the input field
        const container = document.getElementById(field + 'Container');
        const labelText = field === 'actor1' ? 'First Actor' : 'Second Actor';
        const suggestionId = field === 'actor1' ? '1' : '2';
        
        container.innerHTML = `
            <label class="mdc-text-field mdc-text-field--filled" data-mdc-auto-init="MDCTextField">
                <span class="mdc-text-field__ripple"></span>
                <span class="mdc-floating-label" id="${field}-label">${labelText}</span>
                <input type="text" 
                       class="mdc-text-field__input" 
                       id="${field}"
                       aria-labelledby="${field}-label"
                       hx-get="/api/actors/search" 
                       hx-trigger="keyup changed delay:300ms" 
                       hx-target="#suggestions${suggestionId}"
                       hx-include="this"
                       hx-vals='{"field": "${field}"}'
                       name="q">
                <span class="mdc-line-ripple"></span>
            </label>
            
            <div class="suggestions" id="suggestions${suggestionId}"></div>
            <input type="hidden" id="${field}_id" name="${field}_id">
            <input type="hidden" id="${field}_name" name="${field}_name">
        `;
        
        // Initialize the new text field
        if (typeof mdc !== 'undefined') {
            mdc.autoInit(container);
        }
        
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

    trackComparison() {
        if (typeof posthog !== 'undefined') {
            const actor1Name = document.getElementById('actor1_name').value;
            const actor2Name = document.getElementById('actor2_name').value;
            posthog.capture('comparison_started', {
                actor1: actor1Name,
                actor2: actor2Name
            });
        }
    }

    clearInputFields() {
        // Check if we have actor IDs in the URL (from share link)
        const urlParams = new URLSearchParams(window.location.search);
        const hasActor1Id = urlParams.has('actor1_id');
        const hasActor2Id = urlParams.has('actor2_id');
        
         // Don't clear fields if we're loading from a share link
         if (hasActor1Id && hasActor2Id) {
             return;
         }
        
        // Clear all input fields on page load to ensure clean state
        ['actor1', 'actor2'].forEach(field => {
            const inputField = document.getElementById(field);
            if (inputField) {
                inputField.value = '';
            }
            
            // Also clear hidden fields to ensure clean state
            const idField = document.getElementById(field + '_id');
            const nameField = document.getElementById(field + '_name');
            if (idField) idField.value = '';
            if (nameField) nameField.value = '';
            
            // Clear backup fields
            const idBackup = document.getElementById(field + '_id_backup');
            const nameBackup = document.getElementById(field + '_name_backup');
            if (idBackup) idBackup.value = '';
            if (nameBackup) nameBackup.value = '';
        });
    }
}

// Export for use in other modules
window.ActorSearch = ActorSearch;