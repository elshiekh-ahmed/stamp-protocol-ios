# JOEYY

A native SwiftUI customer-loyalty prototype for iOS 18 and later.

## JOEYY Version 3 Iteration Planning
Planned potential v3: 

1. Actual hole punch that comes in and makes the punch?
2. Apple wallet wire impl
3. Gallery view for discoverable places or gallery views in general as opposed to scroll
4. Stackable redeemed tickets? Or have to use before rotating back to 0 stamps?
5. Queued updating for stamp card update in customer of customer facing app
6. Wallet stack for home page as well as group break down to expand group, individual location views
7. Customer dependent reward stacking (we lean towards stacking though)
8. Archive / graveyard for punch cards to see how much youve earned (memories)
9. Default / fall back preset images for customers who haven't set a custom picture yet
10. Redeemed / archive graveyard customized views as well

Shareables:
1. Shared design .md file to describe theming/common colors, common components and how they are rendered/look, and other standardized UI flow

## Run

Open `JOEYY.xcodeproj`, select **JOEYY** and an iPhone simulator, then Run.
No packages, credentials, signing team, or backend are needed for the simulator.
For a physical device, select your signing team in Xcode.

The included project is generated from `project.yml` using XcodeGen.

## Sample businesses

Names and locations come from the businesses' official websites. Offers,
client IDs, artwork, coupons, and transactions are fictional. Nothing here
represents an actual loyalty program or affiliation.

| Business | Location | Demo card |
|---|---|---|
| [Monorail Espresso](https://monorailespresso.com/pages/pike-st) | 510 Pike St, Seattle | 8 stamps for an espresso; starts at 5 |
| [Cloud City Coffee](https://www.cloudcitycoffee.com/pages/where-to-find-cloud-city) | 8801 Roosevelt Way NE, Seattle | 6 stamps for a brewed coffee; starts full |
| [5 Stones Coffee Co](https://5stonescoffeeco.com/pages/kirkland) | 312 Central Way, Kirkland | 10 stamps for a latte; starts at 2 |
| [Saint Bread](https://www.saintbread.com) | 1421 NE Boat St, Seattle | 8 stamps for a pastry; add from Search |
| [Book Larder](https://booklarder.com) | 4252 Fremont Ave N, Seattle | 6 stamps for 10% off one book; add from Search |
| [Gloom Coffee](https://gloom.coffee) | 240 2nd Ave S, Seattle | 8 stamps for an espresso; add from Search |

These are original prototype card treatments, not the businesses' branding.
No merchant logos or photographs are bundled.

## Flow

Fresh installs open a card-led landing with **Customer** and **Business** destinations.
Customer opens the loyalty app. Business opens the business side (below); the app
reopens whichever side was chosen last. Only entering Customer completes customer setup.
Existing welcome completion is preserved. **You > Customer or business** replays setup
from either side without changing saved data.
Choosing Customer opens Home and clears its previous navigation and collection
filter. Closing replay returns to You without changing navigation.

**Home** shows a single-column collection with a full-width card for each place.
Each business has one reward and a fixed
target between 3 and 12 stamps, matching the merchant model's `requiredPunches`
and `rewardDescription`.

Open Monorail and tap **Add demo stamp** three times. A full card stays full
until **Claim reward** is confirmed. Claiming saves a coupon in **Redeemed**
and starts the next card at zero. Cancel leaves the full card untouched.
The prototype blocks additional stamps while full; it does not discard stamps,
bank overflow, or automatically reset a completed card.

This claim-triggered reset is a customer-flow decision, not an implemented
shared backend contract. The merchant app's automatic reward/reset behavior
still needs to be reconciled before integration.

**Redeemed** separates available and used coupons. Three historical sample
coupons are included. Marking a coupon used is a local demo action, happens
once, and does not change stamps. Archived cards retain their stamps, history,
and usable coupons; restore them through the archive button on Home.

**Search** opens with **Discoverable**, a horizontally snapping gallery of
Saint Bread, Book Larder, and Gloom Coffee. These are fixed pilot selections,
not personalized recommendations. Full-bleed posters use original bakery,
bookshop, and coffee artwork unless a merchant supplies a cover photo.
Shared typography and compact captions keep the gallery consistent. Swiping
adds depth and artwork parallax, with a light haptic on each snap. Reduce Motion
or a merchant's motion preference disables parallax, tilt, and scaling.
Opening a place does not join it; **Add card** adds a zero-stamp card to Home.
The three existing cards, balances, and coupons are unchanged.
Typing switches to business-name or exact assigned client GUID matches across
all six places, not neighborhoods or categories. Clearing restores the gallery.
Try Monorail's demo ID:
`6A2E3D81-7B49-4F12-A0C3-819D62E00101`.
**Program details** contains the address, official website, demo rules, and ID.

Save any card with its star, including unfinished cards. Home's collection menu
switches between **All places**, **Favorites**, and named **Groups**. Groups can
contain multiple places, and a place can belong to several groups. Edit names
and membership in **Groups**, or assign a card through its detail options.
Archiving hides a card without losing its favorites or group membership.
Each group has an options menu with Rename and Delete group. Its editor also
supports changing places and deleting the group, with confirmation.
Deleting a group does not remove cards, punches, favorites, or coupons.

**You** contains appearance, eight accents, local notification preferences, and
setup replay. Notifications are not connected. Data/export/reset controls and
prototype sections are no longer part of this screen. No profile form or sign-in
is required.
**Apple Wallet**, customer codes, NFC, authentication, and purchase verification
are not implemented. There are no fake passes or scannable codes.

## Business side

Business owners set up their business, design the card customers collect, and see how often
customers return. It uses the same design system, `MerchantTheme`, and card views as the
customer app, so the card designer previews exactly what customers see.

- **Welcome**: set up a business, or explore **Norema Cafe** sample data (fictional activity).
- **Overview**: lifetime cardholders, plus stamps, rewards earned, and rewards redeemed for
  Today / 7 / 30 / 90 days / All. Shows the live card as a Home collection tile.
- **Card**: stamps for a reward (3–12, `Place.punchRange`), the reward, and the card's
  `MerchantTheme`: contrast-checked light/dark color pairs, typeface, card stock
  (Clipped `rail`, Rounded `cloud`, Square `stone`), cover photo, and motion. The preview uses
  `PlaceGalleryTile`-style tiles and `PunchCard` with an unpublished theme.
  Publishing creates an immutable **version**. Cards with stamps keep their version's rules and
  look until complete; cards with no stamps, new customers, and next cards use the live version.
  The publish confirmation shows how many cards keep their rules and how many switch.
  **Version history** marks each version Live, Finishing, or Retired.
- **Business**: name, logo, location from Apple Maps suggestions, and client ID.
- **You**: shared appearance and accent, **Customer or business**, sample data controls, and
  **Report a bug**. The ladybug on each page also opens a pre-filled GitHub issue in this
  repository with the app version, device, iOS version, and current screen.

Business data is JSON in Application Support, separate from customer data. There is no business
sign-in, server, or link between published business cards and customer search yet; location
search text is sent to Apple Maps. Apple Wallet is unavailable for the same signing reason above.
`-ui-testing -reset-demo` also clears business test data; add `-business-sample` to load Norema.

## Appearance and storage

Native Dynamic Type, light/dark palettes, and accent washes apply throughout.
Merchant themes select contrast-safe paper/ink colors, system typeface families,
original artwork, an optional image, and whether motion is enabled. Detail
shows the cover and a separate punch card; wide layouts place them side by side.
Earned slots cut through the paper instead of showing an emoji or a filled icon.
Cards use fine paper fibers, a lit stock edge, printed numbered targets, and
slightly irregular cut edges. A stamp briefly compresses and tips the card;
Reduce Motion keeps it still. The final target has a double printed ring.
Monorail uses clipped stock corners, Cloud City rounded stock, and 5 Stones
square stock; these follow the existing merchant artwork styles.
Presses have shallow perspective and spring compression; collecting a stamp
punches its slot with a brief impact haptic. Reduce Motion and merchant motion
opt-out remove perspective, spring scaling, and stamp zoom.
Animation never controls loyalty state.

Cards, coupons, events, favorites, groups, themes, and preferences stay in
UserDefaults. Local photo previews are JPEG files in Application Support.
This update preserves v2 punches and coupons; older v2 cards default to not
favorited. The earlier v1 migration replaced the fictional starter set with
fresh program IDs, without assigning old balances to real businesses.
Invalid saved records produce an error rather than being overwritten.

The model retains deletion/reset helpers for testing, but You does not expose
them. Setup replay never calls them. Published image URLs contact their image
host, but no loyalty history is uploaded.
Opening a business website uses its external URL.

## Merchant artwork integration

The merchant app chooses a photo and uploads it directly to the merchant service.
That service publishes an HTTPS cover URL and presentation tokens. Customers
receive those published values, not upload credentials or private image bytes.

`MerchantBrandingStore.applyPublishedBranding(_:)` accepts a JSON-encoded
`PublishedMerchantBranding` containing `merchantID` and `theme`. The prototype
uses `Place.id` as `merchantID`; the production mapping to assigned client GUIDs
is not agreed. Theme fields:

| Field | Value |
|---|---|
| `lightPaper`, `lightInk`, `darkPaper`, `darkInk` | RGB integers, 0 through 16777215; text contrast must be at least 4.5:1 |
| `typeface` | `standard`, `rounded`, `serif`, or `monospaced` |
| `artwork` | `rail`, `cloud`, or `stone`; used when a photo is absent |
| `coverURL` | Optional HTTPS image URL without embedded credentials |
| `allowsMotion` | Boolean; accessibility Reduce Motion always takes precedence |

Use versioned image URLs when replacing artwork. Images load asynchronously,
are limited to 20 MB, downsampled to 1600 pixels, and cached in bounded memory.
Invalid images show an error and retry control on the establishment page.
Theme changes do not change stamps, rewards, groups, or coupons.

**Card options > Preview branding** opens a local photo picker and a published
URL preview. A local photo overrides the published cover until removed. It is
not uploaded. Original sample artwork is used without merchant-provided assets.

There is no configured merchant API, authentication, upload endpoint, or live
branding subscription. The receiving model and image renderer are implemented;
wiring a server response to them requires the real service contract.

## Checks

Apple Wallet remains blocked on signed passes. The simulator's public PassKit
API reports that adding passes is supported, but rejects an unsigned demo
package with "Signature is missing". A fictional reward still needs a signed
`.pkpass`; no certificates or signing keys are bundled. Merchant artwork can be
rendered into pass images later, within Apple's native pass layout.

Product > Test runs model and simulator UI checks: full-card persistence,
claim/cancel/reset, duplicate claim rejection, one-time coupon use, migration,
search, archive/restore, model deletion, role setup/replay, settings, large text, Reduce Motion, and
light/dark contrast, Favorites, Groups, branding validation, image loading,
local photo persistence, and photo-picker cancellation. UI tests use isolated defaults.

```sh
xcodebuild test -project JOEYY.xcodeproj -scheme JOEYY \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

`-skip-welcome -reset-demo` supports repeatable walkthroughs.
`-ui-testing` isolates defaults; `-reset-demo` then clears only test state.
Automated checks do not replace a VoiceOver or physical-device review.
