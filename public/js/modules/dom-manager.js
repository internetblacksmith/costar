// DOM manipulation and element management
class DOMManager {
    // Get element by ID with null checking
    static getElement(id) {
        return document.getElementById(id);
    }

    // Set value of an element if it exists
    static setValue(id, value) {
        const element = this.getElement(id);
        if (element) {
            element.value = value;
        }
    }

    // Clear value of an element if it exists
    static clearValue(id) {
        this.setValue(id, '');
    }

    // Set inner HTML of an element if it exists
    static setHTML(id, html) {
        const element = this.getElement(id);
        if (element) {
            element.innerHTML = html;
        }
    }

    // Add class to element if it exists
    static addClass(id, className) {
        const element = this.getElement(id);
        if (element) {
            element.classList.add(className);
        }
    }

    // Remove class from element if it exists
    static removeClass(id, className) {
        const element = this.getElement(id);
        if (element) {
            element.classList.remove(className);
        }
    }

    // Create actor chip HTML (wrapped in search-input-field to preserve label + layout height)
    static createChipHTML(field, actorName) {
        const labelText = field === 'actor1' ? 'First Actor' : 'Second Actor';
        return `
            <div class="search-input-field">
                <label class="field-label">${labelText}</label>
                <div class="selected-actor-chip" data-field="${field}">
                    <span class="chip-text">${actorName}</span>
                    <button type="button" class="chip-remove" onclick="window.actorSearch.removeActor('${field}')" aria-label="Remove ${actorName}">
                        <span class="material-icons">cancel</span>
                    </button>
                </div>
            </div>
        `;
    }

    // Create search input field HTML (includes suggestions container inside for correct positioning)
    static createTextFieldHTML(field, labelText, suggestionId) {
        return `
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
        `;
    }

    // Create hidden input HTML
    static createHiddenInputs(field, actorId = '', actorName = '') {
        return `
            <input type="hidden" id="${field}_id" name="${field}_id" value="${actorId}">
            <input type="hidden" id="${field}_name" name="${field}_name" value="${actorName}">
        `;
    }

    // Create loading indicator HTML
    static createLoadingHTML() {
        return `
            <div class="loading show">
                <p>Loading filmographies...</p>
                <div class="progress-bar progress-bar--indeterminate">
                    <div class="progress-bar__track">
                        <div class="progress-bar__fill"></div>
                    </div>
                </div>
            </div>
        `;
    }

    // Initialize dynamic content (process HTMX attributes)
    static initializeMDC(container) {
        // Process HTMX attributes on new elements
        if (typeof htmx !== 'undefined') {
            htmx.process(container);
        }
    }
}

// Export for use in other modules
window.DOMManager = DOMManager;
