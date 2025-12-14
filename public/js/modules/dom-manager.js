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

    // Create Material Design chip HTML
    static createChipHTML(field, actorName) {
        return `
            <div class="mdc-chip selected-actor-chip" data-field="${field}" data-mdc-auto-init="MDCChip">
                <div class="mdc-chip__ripple"></div>
                <span class="mdc-chip__primary-action">
                    <span class="mdc-chip__text">${actorName}</span>
                </span>
                <span class="mdc-chip__trailing-icon material-icons" onclick="window.actorSearch.removeActor('${field}')" tabindex="0" role="button">cancel</span>
            </div>
        `;
    }

    // Create Material Design text field HTML
    static createTextFieldHTML(field, labelText, suggestionId) {
        return `
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
    }

    // Initialize Material Design components in a container
    static initializeMDC(container) {
        if (typeof mdc !== 'undefined') {
            mdc.autoInit(container);
        }
        // Also process HTMX attributes on new elements
        if (typeof htmx !== 'undefined') {
            htmx.process(container);
        }
    }
}

// Export for use in other modules
window.DOMManager = DOMManager;