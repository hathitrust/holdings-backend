# Description of Format and Overlap Determinations #
This attempts to describe what this system actually does. This does not attempt to exhaustively describe all corner cases or emergent properties.

## Definitions ##
**Format**
: mono (spm), multi (mpm), serial (ser)

**Cluster**
: Collection of HT Items, Holdings, and Concordance pairs united by a list of OCNs determined to be equivalent.

**Bib Record**
: A preferred record from the Zephir clustering system containing one or more HT Items. Has a single Hathitrust record ID.

**HT Item**
: Volume ID and associated metadata taken from the Hathifiles. 

**Print Serials List**
: List of Record Ids determined to be serials by some unknown UMich process. List is limited to those held by UMich.

**Large Clusters**
: Clusters large enough that they create implementation problems. Identified by an OCN, there are currently 11 on the list.

**Billing Entity**
: The `billing_entity` field taken from the `ht_collections` table associated with a particular HT Item through the collection code. Used for cost allocation when holdings are incomplete or no clustering can be performed. Also has subtle and likely inconsequential implications for items contributed by UCM and KEIO.

**n_enum**
: A normalized enumeration. Description fields are processed for enumeration and chronology. Only enumeration ends up being used. 


## Item Format ##

**Serial**
: Items with a **Bib Record ID** found on the **Print Serials List**, or in a **Large Cluster** 

**Multi-part Monograph**
: Is not a Serial. Shares a **Bib Record** with an item that has a non-empty `n_enum`. [^1]

**Single-part Monograph**
: Is not a Serial or Multi-part

**NB**: A cluster may contain items of multiple formats.  
**NB2**: Format as reported by members is irrelevant.

## Cluster Format ##

**Multi-part Monograph**
: Any of the items in the cluster are MPMs.

**SER / SPM**
: Is not MPM. One or more of the items in the cluster are SPM _and_ one or more of the items in the cluster are SER.

**SER**
: Is not MPM or SER/SPM. Any of the items in the cluster are SER (and by implication ALL are SER).

**SPM**
: Is not MPM, SER/SPM, or SER.

## Cost Allocation ##

**Target Cost**
: Set by the Board and Executive Director. Portion of the budget to be paid for by item allocations.

**Cost Per Volume**
: Target Cost / Total Number of HT Items

**Member Weight**
: A number assigned to a member by the ED that determines their share of Public Domain costs. 

**Total Weight**
: The sum of member weights found in the `ht_billing_members` table of the holdings database. **Which process/system has ownership of this table?**

**Public Domain Cost**
: Cost Per Volume * Number of Public Domain Volumes (see Public Domain vs In-Copyright)

**Public Domain Cost for Member**
: Total Public Domain Cost / Total Weight * Member Weight

**Extra Per Member**
: The IC Costs assigned to Hathitrust / Number of members found in the `ht_billing_members` table that aren't Hathitrust. Hathitrust has IC costs due to being the billing entity for some items.

**HScore**
: A share of an HT Item.

**Total HScore (for Member)**
: Sum of HScores for Member for each of SPM, MPM and SER

**Total IC Cost for Member**
: Total HScore for Member * Cost Per Volume

**Total Cost for Member**
: Total IC Cost for Member + Total PD Cost for Member + Extra Per Member


### Public Domain vs In-Copyright ###
For cost allocation purposes, items with access "allow" in the Hathifiles are considered "public domain" and access "deny" are considered "in copyright". Rationale for the "allow" and "deny" found in the Hathifiles is underdefined. 

## Item Overlap ##
Determining who holds a particular IC item.

For items in **clusters** that are not MPM, all organizations with a holding in the cluster and the billing entity for the item are allocated a share. 

For items in **clusters** that are MPM, the process is more complicated. Organizations with holdings:
- Organizations with holdings with empty **n_enum**. The reverse is **not** true; i.e. Items with empty n_enum don't match everything.
- Organizations with holdings with an **n_enum** matching the **n_enum** of the Item.
- Organizations with **holdings** in the cluster with **n_enum** that don't match any of the **n_enum** found in any of the Items in the cluster. [^2]
- Billing entity for the item.

**NB**: Billing entities apply only to the Item they are on. For example, a billing entity on an HT Item with an empty n_enum will **not** match other items in the cluster.

## Frequency Table ##
Item shares are held in a frequency table separated by member and **item** format.[^3] This gets compiled into per format per member cost allocations. 

[^1]: System only uses n_enum which is likely wrong, but n_chron and n_enum_chron exist so changes should be easy.

[^2]: This can lead to cases where a member providing more data or HT ingesting more items can reduce access/cost.

[^3]: Implementation detail: `<member> => <format> : <num of orgs that hold a thing> : <frequency>`
Total hscore for a particular member and format is thus  ∑(1 / number of orgs * frequency). This doubles as a data structure for overlap histograms which is why it is more complicated than it needs to be for only cost allocation.
