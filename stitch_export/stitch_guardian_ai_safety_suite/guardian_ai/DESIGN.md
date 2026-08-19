---
name: Guardian AI
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#e3bdc5'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#aa8890'
  outline-variant: '#5b3f46'
  surface-tint: '#ffb1c5'
  primary: '#ffb1c5'
  on-primary: '#650030'
  primary-container: '#ff4a90'
  on-primary-container: '#590029'
  inverse-primary: '#ba005d'
  secondary: '#ffb0cd'
  on-secondary: '#640039'
  secondary-container: '#aa0266'
  on-secondary-container: '#ffbad3'
  tertiary: '#ddb7ff'
  on-tertiary: '#490080'
  tertiary-container: '#b76dff'
  on-tertiary-container: '#400071'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffd9e1'
  primary-fixed-dim: '#ffb1c5'
  on-primary-fixed: '#3f001b'
  on-primary-fixed-variant: '#8e0046'
  secondary-fixed: '#ffd9e4'
  secondary-fixed-dim: '#ffb0cd'
  on-secondary-fixed: '#3e0022'
  on-secondary-fixed-variant: '#8c0053'
  tertiary-fixed: '#f0dbff'
  tertiary-fixed-dim: '#ddb7ff'
  on-tertiary-fixed: '#2c0051'
  on-tertiary-fixed-variant: '#6900b3'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 42px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding: 24px
  stack-gap: 16px
  section-gap: 40px
  gutter: 16px
---

## Brand & Style

The design system embodies "Protective Elegance"—a fusion of high-end luxury fintech aesthetics with the reliable, instantaneous nature of personal safety. It targets a discerning audience that values both personal security and sophisticated digital experiences. 

The visual direction is a hybrid of **Glassmorphism** and **Modern Corporate** (inspired by HIG and Material 3). It utilizes deep, matte surfaces punctuated by vibrant, neon-fused glows and frosted glass layers. The emotional response is one of calm confidence; the UI feels premium enough to be a concierge service, yet urgent enough to be a lifeline. 

Key stylistic pillars include:
- **Depth through Translucency:** Multiple layers of frosted glass to signify information hierarchy.
- **Luminous Accents:** Using primary pinks and lavender glows to draw the eye to critical safety actions.
- **Soft Precision:** High-fidelity detailing with subtle borders and expansive white space.

## Colors

The palette is anchored in a sophisticated "Midnight Matte" foundation to ensure the primary pinks and lavender accents feel like high-end signals rather than playful toys.

- **Primary (#FF2E88):** "Pulse Pink"—used for critical actions, SOS triggers, and active safety states.
- **Secondary Palette:** A range of Rose and Soft Pinks (#F472B6) and Lavenders (#D8B4FE) used for non-critical status indicators and secondary data visualization.
- **System Backgrounds:** 
    - **Dark Mode (Default):** Matte Black (#000000) for the base, with Deep Navy/Slate (#0F172A) for elevated containers.
    - **Light Mode:** Pure White base with ultra-thin Lavender-tinted greys for depth.
- **Accents:** "Glass White" (White at 10-20% opacity) and "Aura Glows" (blurred radial gradients of #A855F7) used behind glass cards to create a sense of dimensionality.

## Typography

This design system utilizes **Plus Jakarta Sans** for its contemporary, open apertures and high legibility. The type scale is intentionally dramatic, using large display sizes for status summaries (e.g., "You are safe") to instill immediate confidence.

- **Headlines:** Use Bold or SemiBold weights with tight letter-spacing for a "Fintech" editorial look.
- **Body:** Regular weights with generous line height (1.5x) to maintain clarity during high-stress interactions.
- **Labels:** Uppercase tracking is applied to small labels to provide a structured, technical feel similar to luxury instrument clusters.
- **Mobile Scaling:** Headline sizes drop by approximately 20-25% on mobile devices to maintain a balanced information density.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** with fixed-width maximums for desktop. It relies on generous, airy margins to evoke a "Premium" feel.

- **Safe Areas:** A minimum of 24px horizontal padding on all mobile screens to prevent UI elements from feeling cramped.
- **Vertical Rhythm:** Built on an 8px baseline. Grouped elements (like an input and its label) use 8px spacing; distinct components use 16px or 24px.
- **The "Floating" Effect:** Content is often housed in cards that do not touch the screen edges, creating a "floating" look characteristic of high-end iOS apps.
- **Mobile Reflow:** On mobile, columns collapse to a single stack, but cards maintain their 24px internal padding to preserve the luxury aesthetic.

## Elevation & Depth

This design system uses a multi-layered elevation model combining **Tonal Layers** and **Glassmorphism**:

1.  **Level 0 (Floor):** Pure Matte Black or Deep Slate. This is the "infinite" base.
2.  **Level 1 (Surface):** Slightly elevated containers using a 2% white overlay or a subtle dark grey tint.
3.  **Level 2 (Glass Cards):** The signature component. These use `backdrop-filter: blur(20px)` with a 10% white semi-transparent fill. They feature a 0.5px "inner glow" stroke to define edges.
4.  **Level 3 (Floating Sheets):** Bottom sheets and modals. These use a stronger blur (40px) and a distinctive drop shadow (0px 20px 40px rgba(0,0,0,0.4)).

**Shadows:** Shadows are never pure black; they are "Ambient Shadows" tinted with the primary pink or purple color of the element above them, creating a soft glow effect.

## Shapes

The shape language is defined by **Large, Organic Roundedness**. 

- **Primary Corners:** All main cards and containers utilize a **24px (1.5rem)** corner radius.
- **Buttons & Inputs:** Follow the same 24px radius, creating a consistent "pill-adjacent" look that feels soft and approachable.
- **Small Elements:** Chips and progress indicators use a fully circular (pill) radius.
- **Visual Consistency:** The large radius is essential to balance the "technical" nature of an AI safety app with a sense of "human" protection.

## Components

### Buttons
- **Primary SOS:** A large, circular or wide-pill button with a #FF2E88 gradient and a soft pink outer glow. Should feel "pressable" with a subtle inner shadow.
- **Secondary Glass:** Transparent background with the 20px backdrop blur and a thin white border.

### Glass Cards
- Used for location data, AI status updates, and contact lists. These feature the 24px rounded corners and the signature frosted glass effect.

### Action Cards
- High-contrast cards used for primary features (e.g., "Start Walk Home"). They use a subtle gradient from Deep Pink to Soft Purple.

### Status Chips
- Small, pill-shaped indicators. "Active" states use a pulsing animation; "Safe" states use a soft lavender tint.

### Progress Rings
- Thin, elegant circular strokes used for timers or battery levels. Use a #FF2E88 to #A855F7 gradient stroke.

### Floating Bottom Sheets
- Sheets that do not touch the bottom of the screen. They hover 16px above the home indicator, utilizing the 24px rounded corners on all sides and a heavy backdrop blur to separate from the map or main feed.

### Input Fields
- Dark, recessed fields with a 1px border that illuminates in Pink (#FF2E88) when focused.