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

The gear database contains all gear and gear attributes.  It is composed of sections.  Each section contains a list of items (one per line).  Sections are separated by a blank line.  Each item is broken up into fields.  Fields are separated by semi-colons.  The first field is the item id.  Succesive fields are attributes.  
Supported attributes include weight and description.  Weights are recognized by unit suffix.  Anything not recognized as a weight is automatically used as a description.

Example Database:

```
Section0
Item0;2lb6oz;Item0 Description
Item1;5oz;Item1 Description

Section1
Item2;1oz
Item3;23g;Item3 Description
```

### Manifest

The gear manifest defines what the output looks like.  It is broken up into sections.  A section must have one or more lines.  Each line references a piece of gear or a previous section.

```
Section0
+1 Item0
+2 Item1

Section1
+1 section::Section0
+3 Item2
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
 +3 Item2                3oz
SUBTOTAL            2lb 14oz
```

