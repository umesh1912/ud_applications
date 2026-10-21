# Jhatpat design system — "the ticket"

Recharges and bills are quick, everyday errands, so the app feels like grabbing a ticket at a counter.

- **Signature:** the **ticket** (`Ticket` in `widgets.dart`): notched sides and a perforated tear line between the main part and the stub. Plans, due bills, offers and the checkout summary are all tickets. After paying you get a **receipt** with a torn zigzag edge, and a **scratch card** you scratch with your finger.
- **Colour:** cool grey `#ECEEF3`, ink `#191A2E`, saffron `#F26B1D` for paying, mint `#00876F` for cashback and success, red `#CF3434` for failures. Full dark mode.
- **Type:** Unbounded (wide and punchy) for prices and headings; Manrope for everything else, with tabular figures for amounts.
- **Flow:** number → plans (or fetch bill) → checkout → receipt, with the operator and circle detected automatically and failures refunded with a visible tracker.
