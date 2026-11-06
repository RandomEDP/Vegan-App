# TLLV for iOS

A native SwiftUI app for The Little London Vegan (thelittlelondonvegan.com).

## Run it

1. On a Mac with Xcode 16 or newer, open `TLLV.xcodeproj`.
2. Select the **TLLV** target, then **Signing & Capabilities**, and choose your Apple developer team. Change the bundle ID (`com.thelittlelondonvegan.app`) if you need to.
3. Pick an iPhone simulator and press Run (⌘R).

Minimum iOS version: 18.0. The app works on iPhone and iPad.

## How it's built

- **Data**: the app reads the same public endpoints as the website: `/api/catalog` for reviews, guides, news and About content, and `/api/perks` for perks. It caches the last response on device and ships with a bundled snapshot (`Resources/catalog-seed.json`), so it opens instantly and works offline. Pull to refresh on any screen.
- **Newsletter**: signs people up through the site's own `/api/newsletter` endpoint.
- **Saved**: favourites and custom lists are stored on the device.
- **No dependencies**: it uses only SwiftUI, MapKit, CoreLocation and SafariServices.

## Screens

| Tab | What it is | Website equivalent |
| --- | --- | --- |
| Discover | Wordmark hero, latest reviews carousel, Clare's guides, perks, news, Meet Clare and the newsletter | Home |
| Explore | A full MapKit map with pink (fully vegan) and lavender (vegan-friendly) pins, a list view, search, quick filter chips and a filter sheet for vegan status, price, region, cuisine, open now, Clare's faves, dog-friendly, gluten-free friendly and bookings | Map plus Filters |
| Guides | London collections such as Clare's Favourites and Date Night, plus travel guides grouped by country. Each guide has a map | Guides |
| Perks | Restaurant and brand offers with the terms for each | Perks |
| Saved | Favourites and your own lists, which you can reorder, rename and see on a map | Lists and Plan |

The restaurant page follows the layout of Apple Maps place cards: a photo gallery, then Directions, Call, Book and Website buttons, Clare's quote and fave dish, any perk, a map snippet, opening hours (shown in London time, with whether it's open now), details and tags, and links to the review, Instagram and Last Orders.

All of it follows Apple's guidelines: a standard tab bar, large titles, inset grouped lists, SF Symbols, swipe actions, context menus with previews, sheets with detents, haptics, Dynamic Type, Dark Mode and VoiceOver labels.

## Premium

The app uses the same accounts and the same rules as the website. Members sign in inside the app with their thelittlelondonvegan.com email and password (`/api/auth/login`), and the app reads their membership from `/api/account`.

What's locked follows the website's own `featureAccess` table:

| Free | Premium or trial | Paid Premium only |
| --- | --- | --- |
| Latest reviews, restaurant pages, travel guides, news, name and area search | Interactive map, filters and dish search, Open now and Nearest, Clare's London guides, Clare's fave dish, favourites, lists | Redeeming perks (`canRedeem` from `/api/perks`) |

Perks can be browsed by anyone. Members unlock and redeem them through the site's own `/api/perks/{id}/unlock` and `/redeem` endpoints, so usage limits are shared with the website.

**Payment happens on the website.** Start trial and Upgrade open the site's Stripe checkout in Safari. Apple normally requires digital subscriptions sold inside an iOS app to use in-app purchase, so this is likely to be raised in App Review. The usual options are to add StoreKit subscriptions that the backend also recognises, or to remove the upgrade buttons and only let existing members sign in (the "reader app" approach).

## Not built yet

- **Day planner**: the website's Plan itineraries aren't in the app.
- **Synced favourites**: favourites and lists are stored on the device and don't sync with the website account yet.

## Build check

Every push and pull request is built on a GitHub macOS runner (`.github/workflows/ios-build.yml`).
