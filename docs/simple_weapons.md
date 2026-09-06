# Simple weapons

Source: Project ARTON Weapon System Design Specification, sections 5 and 7.1.
All six Simple weapons are available in the creation equipment catalog and the
prototype player inventory. Existing starting equipped items remain unchanged.

| Weapon | Base damage | Range | Attribute | Defense | Notes |
| --- | --- | --- | --- | --- | --- |
| Dagger | 3 Pierce | 5 ft | DEX | Reflex | +1 Hit, 15% critical |
| Club | 5 Blunt | 5 ft | STR | Fortitude | No critical |
| Iron Sword | 5 Slash | 5 ft | STR | Reflex | Existing weapon preserved |
| Hand Axe | 5 Slash | 5 ft | STR | Reflex | Thrown tag |
| Short Spear | 4 Pierce | 5 ft | STR | Reflex | Thrown tag |
| Shortbow | 4 Pierce | 30 ft | DEX | Reflex | Two Handed, no melee Opportunity |

All primary attacks cost 1 AP. New melee weapons reuse the lunge animation.
Reflex is used for new weapons unless the design explicitly specifies Fortitude.

All 16 weapon traits in section 5 already exist and are reused, not duplicated:
Simple, Advanced, Melee, Ranged, Thrown, Reach, Two Handed, Shield Compatible,
Heavy, Light, Finesse, Reload, Dual Weapon, Slash, Pierce, Blunt.
Dagger's precision/light properties are tagged Finesse, Light and Dual Weapon;
these do not independently grant extra attacks or bonuses.

## Remaining mechanics

Hand Axe and Short Spear now have a separate Throw entry in the Attack menu,
at 15 ft for 1 AP. Throwing consumes the held inventory item upon declaration,
even on a miss or a subsequent defensive Reaction. Returning prevents consumption
and leaves the weapon equipped. Failed validation or cancelled targeting costs
no item. There is no ground pickup/recovery: the latest user rule replaces that
earlier proposal. Add Returning to the weapon attack's traits to opt in.
Their primary melee attacks remain at 5 ft and do not consume the item. Shortbow's
proposed adjacent penalty has no defined numeric rule and is not applied.
Proficiency restrictions, Reload/ammo, and Dual Weapon extra attacks are still
tag-only mechanics. Weapon-specific abilities proposed in section 8 (such as
Exploit Opening and Concussive Blow) are not added by this roster change.

Existing characters already instantiated in memory are not migrated; start a new
prototype battle or create a new character to use the expanded inventory.
