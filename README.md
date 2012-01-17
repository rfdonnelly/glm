# Gear List Manager

## Description

Manage lists of gear.

glm was created to manange backpacking gear where every ounce counts.

## Usage

```
glm <database> <manifest>
```

glm requires two files: the gear database and the gear manifest

### Database

The gear database contains all gear and gear attributes.  It is composed of items.  Items are defined by the item keyword followed by the item id then an opening brace.

Items may contain attributes and associated values (one per line).  Values may contain spaces.
Supported attributes include weight and description.  Weights are recognized by unit suffix.

Items may be nested.  Items are identified by their full id.  For a nested item with id 'child' and parent item id of 'parent', its full id would be 'parent::child'.

Item format:

```
item <id> {
    <attribute> = <value>
    <attribute> = <value>
    
    item <id> { <attr> = <value> }
}
```

Example Database:

```
item Item0 { weight = 1lb 6oz }

item Item1 {
    weight = 5oz
    desc = Item1 Description

    item Item2 { weight = 3oz }
}
```

### Manifest

The gear manifest defines what the output looks like.  It is broken up into sections.  A section must have one or more lines.  Each line references a piece of gear or a previous section.

```
Section0
+1 Item0
+2 Item1

Section1
+1 section::Section0
+3 Item1::Item2
```

### Output

Given the above database and manifest, glm will output the following:

```
SECTION0
 +1 Item0            2lb 6oz -- Item0 Description
 +2 Item1                5oz -- Item1 Description
SUBTOTAL            2lb 11oz

SECTION1
 +1 SECTION0        2lb 11oz
 +3 Item1 Item2          3oz
SUBTOTAL            2lb 14oz
```

