// Field state management
class FieldManager {
    // Get field configuration
    static getFieldConfig(field) {
        return {
            labelText: field === 'actor1' ? 'First Actor' : 'Second Actor',
            suggestionId: field === 'actor1' ? '1' : '2'
        };
    }

    // Set actor values in all related fields
    static setActorValues(field, actorId, actorName) {
        // Set main hidden fields
        DOMManager.setValue(`${field}_id`, actorId);
        DOMManager.setValue(`${field}_name`, actorName);
        
        // Set backup fields
        DOMManager.setValue(`${field}_id_backup`, actorId);
        DOMManager.setValue(`${field}_name_backup`, actorName);
    }

    // Clear actor values from all related fields
    static clearActorValues(field) {
        this.setActorValues(field, '', '');
    }

    // Clear suggestions for a field
    static clearSuggestions(field) {
        const { suggestionId } = this.getFieldConfig(field);
        DOMManager.setHTML(`suggestions${suggestionId}`, '');
    }

    // Clear input field
    static clearInputField(field) {
        DOMManager.clearValue(field);
    }

    // Get actor values from fields
    static getActorValues(field) {
        return {
            id: DOMManager.getElement(`${field}_id`)?.value || '',
            name: DOMManager.getElement(`${field}_name`)?.value || ''
        };
    }

    // Clear all fields
    static clearAllFields() {
        ['actor1', 'actor2'].forEach(field => {
            this.clearInputField(field);
            this.clearActorValues(field);
        });
    }

    // Check if loading from share link
    static isShareLink() {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.has('actor1_id') && urlParams.has('actor2_id');
    }
}

// Export for use in other modules
window.FieldManager = FieldManager;