# LootWatch

A script for only looting specific items. This script is adapted from loot n scoot.

## Requirements

- MacroQuest (Next) w/ Lua

## Installation

Download `LootWatch` and extract it into your MQ lua directory

## Usage

### Running

Start script with `/lua run LootWatch`

### Configuration

Configuration files found under the MQ config directory

#### LootWatch.ini

``` ini
[Settings]
Enabled=true
LootChannel=bc
ReportLoot=true
CorpseRadius=100
SaveBagSlots=1
CombatLooting=false
MobsTooClose=100
DisableChaseOnLoot=false
```

#### LootWatch_Items.ini

``` ini
[Items]

Some Item=true
Some Other Item=true
```

