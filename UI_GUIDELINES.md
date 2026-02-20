# UI Guidelines for CoStar

This document captures all UI/UX decisions and guidelines implemented based on user feedback during development.

## Actor Portrait Section

### Desktop Layout
- Actor portraits are displayed horizontally at the top of the timeline
- The section is **sticky** - remains visible when scrolling
- When scrolling (sticky activated), the section shrinks by 30% vertically:
  - Portrait images: 120x180px → 84x126px
  - Font sizes and padding reduce proportionally
  - Smooth transition animation (0.3s ease)

### Mobile Layout
- Actor portraits remain **horizontal** (never stack vertically)
- Left actor at 25% from left edge, right actor at 25% from right edge
- Share button centered between them
- Same sticky behavior as desktop with 30% shrink when scrolled

### Portrait Alignment
- Both actor portraits must be perfectly aligned vertically
- Use `align-items: flex-start` to ensure top alignment
- Remove any margins that could cause misalignment

## Timeline Design

### Desktop Timeline
- Single vertical line in the center
- Movies alternate left/right based on actor
- Shared movies appear in the center with special styling

### Mobile Timeline
- **Dual vertical lines** (no center line)
- Left line at 12.5% from edge (primary color)
- Right line at 12.5% from edge (secondary color)
- Lines start below actor names, not at portrait bottom
- Actor portraits centered above their respective timeline lines
- Timeline dots on each line for the respective actor's movies
- Shared movies have dots on both lines with connecting line

### Mobile-Specific Details
- Movie cards display in single column
- Full movie information visible (title, actor name, character)
- Actor badges (1 or 2) on movie cards to indicate which actor
- Shared movies have special accent color border

## Share Functionality

### Share Button
- **Square icon-only button** (48x48px, 36x36px when stuck)
- Located between actor portraits in the header
- Uses Material Design raised button styling
- Same hover behavior as other buttons (primary → secondary color)
- No text label, only share icon

### Share URL Behavior
- URL format: `/?actor1_id=123&actor2_id=456`
- When loading from share link:
  - Actor names fetched server-side for instant display
  - Search inputs replaced with actor selection pills immediately
  - Timeline comparison triggers automatically
  - No delays - near-instant experience
- Pills show the same way as manual selection

## Actor Selection

### Search Behavior
- HTMX-powered instant search with loading indicators
- Search inputs replaced with "pills" when actor selected
- Pills have remove (X) button to clear selection

### Share Link Loading
- Pre-populated actors show as pills, not in input fields
- Backup hidden fields ensure data persistence
- Handles missing actor names gracefully with client-side fallback

## Loading States

### Search Loading
- Spinner with "Searching actors..." text
- Uses `.htmx-indicator` class for HTMX integration
- Smooth fade in/out transitions

### Timeline Loading
- Material Design linear progress bar
- Appears in timeline area during comparison

## Responsive Breakpoints

- Desktop: > 768px
- Mobile: ≤ 768px  
- Small mobile: ≤ 480px

## Color Usage

- Primary color: Actor 1 timeline and elements
- Secondary color: Actor 2 timeline and elements
- Accent color: Shared movies and special indicators
- Follow existing CSS variables for consistency

## Animation Guidelines

- Sticky header transitions: 0.3s ease
- Loading indicators: Smooth fade transitions
- No jarring or instant changes
- Use `requestAnimationFrame` for DOM updates after state changes

## Accessibility

- All interactive elements have proper labels
- Share button uses icon but includes screen reader text
- Timeline maintains logical reading order
- Proper focus states for keyboard navigation

## Performance

- Minimize delays for share link loading
- Pre-populate data server-side when possible
- Use efficient selectors and avoid redundant DOM operations
- Cache actor data appropriately

---

*These guidelines should be followed for any future redesigns or modifications to maintain consistency and user experience.*