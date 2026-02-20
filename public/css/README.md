# CSS Architecture - CoStar

## Overview

The CoStar CSS architecture follows a modular, component-based approach with clear separation of concerns. The stylesheets are organized using the ITCSS (Inverted Triangle CSS) methodology for better scalability and maintainability.

## Directory Structure

```
css/
├── main.css              # Main entry point - imports all other files
├── base/                 # Foundation styles
│   ├── reset.css        # Modern CSS reset
│   ├── variables.css    # CSS custom properties & theme variables
│   └── typography.css   # Typography system
├── components/          # Component-specific styles
│   ├── header.css       # Header component
│   ├── search.css       # Search functionality
│   ├── timeline.css     # Timeline visualization
│   ├── movies.css       # Movie cards and lists
│   ├── loading.css      # Loading states
│   ├── footer.css       # Footer component
│   ├── actor-portrait.css # Actor portrait styling
│   └── mdc-overrides.css # Material Design Component overrides
├── utilities/           # Utility classes
│   ├── helpers.css      # Helper/utility classes
│   └── animations.css   # Animation keyframes and classes
├── responsive.css       # Responsive breakpoints and rules
└── modern-ui.css       # Modern UI enhancements

```

## CSS Methodology

### 1. Base Layer
- **reset.css**: Modern minimal CSS reset for consistent cross-browser styling
- **variables.css**: CSS custom properties for theming, colors, spacing, and transitions
- **typography.css**: Font families, sizes, and text utilities

### 2. Components Layer
Individual component styles that are:
- Self-contained and scoped
- Follow BEM-like naming when needed
- Use CSS custom properties for theming

### 3. Utilities Layer
- **helpers.css**: Single-purpose utility classes for common patterns
- **animations.css**: Reusable animation keyframes and classes

### 4. Layout Layer
- **responsive.css**: Media queries and responsive design patterns

### 5. Theme Layer
- **modern-ui.css**: Progressive enhancements and modern UI features

## Design System

### Colors
All colors are defined as CSS custom properties in `variables.css`:
- Primary colors: Blue palette for main actions
- Secondary colors: Cyan palette for secondary elements
- Accent colors: Amber palette for highlights
- Semantic colors: Success (green) and Error (red)

### Spacing
Consistent spacing system based on 8px unit:
- `--spacing-xs`: 4px
- `--spacing-sm`: 8px
- `--spacing-md`: 16px
- `--spacing-lg`: 24px
- `--spacing-xl`: 32px
- `--spacing-2xl`: 48px

### Typography
System fonts with fallbacks:
- Primary: System UI fonts for body text
- Display: System UI fonts for headings

### Animations
Consistent timing functions:
- `--transition-fast`: 150ms
- `--transition-normal`: 250ms
- `--transition-slow`: 400ms

## Theme Support

The application supports light and dark themes using CSS custom properties. Theme switching is handled by adding `[data-theme="dark"]` to the root element.

## Utility Classes

The utility classes follow a naming convention similar to Tailwind CSS for familiarity:
- Display: `.hidden`, `.block`, `.flex`
- Spacing: `.m-{size}`, `.p-{size}`
- Text: `.text-{size}`, `.font-{weight}`
- Colors: `.text-{color}`, `.bg-{color}`
- Animations: `.animate-{name}`

## Best Practices

1. **Use CSS Custom Properties**: For any value that might change with themes
2. **Component Scope**: Keep component styles isolated and specific
3. **Utility First**: Use utility classes for common patterns before writing custom CSS
4. **Mobile First**: Write base styles for mobile and enhance for larger screens
5. **Performance**: Minimize specificity and avoid deep nesting

## Browser Support

The CSS is written to support modern browsers with graceful degradation:
- Chrome/Edge (last 2 versions)
- Firefox (last 2 versions)
- Safari (last 2 versions)
- Mobile browsers (iOS Safari, Chrome for Android)

Features like CSS Grid, Custom Properties, and modern selectors are used with appropriate fallbacks.