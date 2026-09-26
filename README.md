# Kehet's AutoRoll

A World of Warcraft addon that rolls on group loot for you. You decide how it rolls with a list of rules that you edit in game.

## Rules

When a loot roll starts, the addon checks the rules from top to bottom. The first enabled rule whose conditions all match decides the roll. If no rule matches, the roll window stays open and you roll yourself.

Each rule has a name, a roll and a list of conditions. The roll is Need, Greed, Disenchant, Pass or Roll manually. Roll manually stops the check and leaves the roll to you.

If the roll of a matching rule is not available for the item, the next rule is checked. For example, a Need rule never matches an item that your class cannot use.

A rule without conditions matches every item. Put it last to catch everything the other rules did not.

## Conditions

| Condition | Compares |
|---|---|
| Can roll Need | Yes or No |
| Can roll Greed | Yes or No |
| Can roll Disenchant | Yes or No |
| Binds when picked up | Yes or No |
| You can equip | Yes or No. Yes for gear your character can wear now. Gear with red text in its tooltip, such as the wrong armor type, weapon type, class or level, is No. Items that are not gear, and bags, are also No. |
| Your armor type | Yes or No. Yes for cloth, leather, mail or plate gear of the heaviest armor type your character has learned, for example mail for a shaman. Never matches rings, necks, trinkets, cloaks, shields and off-hands. |
| Item level | A number |
| Item level vs equipped | The item level minus the item level you wear in that slot |
| Quality | Poor to Heirloom. Compare with at least, at most and so on, or pick several qualities. |
| Item type | Armor, Weapon, Consumable, Gem, Trade Goods, Recipe, Quest, Miscellaneous, Glyph or Battle Pet |
| Item subtype | For example Armor: Cloth, Weapon: Staves or Recipe: Tailoring |
| Equip slot | Head, Trinket, Two-Hand and the other slots. Never matches items that cannot be equipped. |
| Already known | Yes or No. Yes for recipes, mounts, pets and other items your character has already learned. |
| Already owned | Yes or No. Yes if the same item is in your bags, in your bank or worn. |
| Zone type | Outside, Dungeon, Raid, Scenario, Battleground or Arena. Where you are when the loot drops. |
| In a finder group | Yes or No. Yes in groups made by the Dungeon Finder, Raid Finder or Scenario queue. |
| Name | Text the name contains or does not contain |

For Quality, Item type, Item subtype, Equip slot and Zone type, "is" and "is not" take several values. The condition "Equip slot is Finger or Trinket" matches rings and trinkets.

For Item level vs equipped, a value below 0 means the item is worse than what you wear. For rings, trinkets and one-handed weapons, the weaker of the two slots is used. An empty slot counts as item level 0. The condition never matches items that you cannot equip.

## Default rules

| # | Name | Rule |
|---|---|---|
| 1 | Cannot need | If Can roll Need is No, then Greed |
| 2 | Not equippable armor | If Item type is Armor and Your armor type is No, then Greed |
| 3 | Not equippable weapon | If Item type is Weapon and You can equip is No, then Greed |

You can edit, reorder, disable and delete the rules. Restore default rules brings them back.

## Settings

Open the settings with `/autoroll`, or open Options > AddOns > Kehet's AutoRoll.

| Setting | Default | Effect |
|---|---|---|
| Roll automatically | On | Roll on group loot with your rules |
| Print rolls to chat | On | Print each automatic roll and the rule that made it |
| Confirm bind-on-pickup rolls | On | Accept the bind question for rolls that the addon makes. Rolls you make yourself still ask. |
| Confirm disenchant rolls | On | Accept the disenchant question for rolls that the addon makes. Rolls you make yourself still ask. |
| Dry run | Off | Check the rules and print what would be rolled, but do not roll. Chat messages are always on in dry run. |

Settings and rules are saved in profiles. By default all characters share the Default profile. Use the Profiles tab to give a character its own rules.

## Commands

Use `/autoroll` or `/kar`.

| Command | Action |
|---|---|
| `/autoroll` | Open the settings |
| `/autoroll on` | Turn automatic rolling on |
| `/autoroll off` | Turn automatic rolling off |
| `/autoroll dry` | Turn dry run on or off |
| `/autoroll rules` | List the rules in chat |
| `/autoroll test <item link>` | Show which rule an item matches. Shift-click an item to insert the link. The test assumes that Need, Greed and Disenchant are all available. |

## Requirements

- World of Warcraft: Mists of Pandaria Classic
- The [Ace3](https://www.curseforge.com/wow/addons/ace3) addon

## License

MIT. See `LICENSE`.
