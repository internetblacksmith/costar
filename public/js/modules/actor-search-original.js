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
                <div class="progress-bar progress-bar--indeterminate">
                    <div class="progress-bar__track">
                        <div class="progress-bar__fill"></div>
                    </div>
                </div>
            </div>
        `;
        
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
        const labelText = field === 'actor1' ? 'First Actor' : 'Second Actor';
        container.innerHTML = `
            <div class="search-input-field">
                <label class="field-label">${labelText}</label>
                <div class="selected-actor-chip" data-field="${field}">
                    <span class="chip-text">${actorName}</span>
                    <button type="button" class="chip-remove" onclick="window.actorSearch.removeActor('${field}')" aria-label="Remove ${actorName}">
                        <span class="material-icons">cancel</span>
                    </button>
                </div>
            </div>
            <input type="hidden" id="${field}_id" name="${field}_id" value="${actorId}">
            <input type="hidden" id="${field}_name" name="${field}_name" value="${actorName}">
        `;
        
        // Show success notification
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
            <div class="search-input-field">
                <label class="field-label" for="${field}">${labelText}</label>
                <input type="text" 
                       class="search-input" 
                       id="${field}"
                       placeholder="${labelText}"
                       aria-labelledby="${field}-label"
                       hx-get="/api/actors/search" 
                       hx-trigger="keyup changed delay:300ms" 
                       hx-target="#suggestions${suggestionId}"
                       hx-include="this"
                       hx-vals='{"field": "${field}"}'
                       name="q">
                <div class="suggestions" id="suggestions${suggestionId}"></div>
            </div>
            <input type="hidden" id="${field}_id" name="${field}_id">
            <input type="hidden" id="${field}_name" name="${field}_name">
        `;
        
        // Process HTMX on new elements
        if (typeof htmx !== 'undefined') {
            htmx.process(container);
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
