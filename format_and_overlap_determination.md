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
: Volume ID and associated metadata taken from the [Hathifiles](https://www.hathitrust.org/hathifiles).

**Print Serials List**
: List of Record Ids determined to be serials by some unknown UMich process. List is limited to those held by UMich.

**Large Clusters**
: Clusters large enough that they create implementation problems. Identified by an OCN, there are currently 11 on the list.

**Billing Entity**
: The `billing_entity` field taken from the `ht_collections` table associated with a particular HT Item through the collection code. Billing Entity is used for cost allocation when a member's submitted holdings do not include all of their deposited HT Items, or no clustering can be performed due to a lack of OCNs. This also has subtle and likely inconsequential implications for HT Items contributed by UCM and KEIO.

**Collection Code**
: An [admistrative code](https://www.hathitrust.org/internal_codes) used to share information between Zephir and the Hathitrust repository.

**n_enum**
: A normalized enumeration. Description fields in the Hathifiles and submitted holdings are processed for enumeration and chronology. Only enumeration ends up being used. 


## HT Item Format ##
Every HT Item has one and only one format. This format is used to calculate the Cluster Format.

**Serial**
: HT Items with a **Bib Record ID** found on the **Print Serials List**, or in a **Large Cluster** 

**Multi-part Monograph**
: Is not a Serial. Shares a **Bib Record** with an HT Item that has a non-empty `n_enum`. [^1]

**Single-part Monograph**
: Is not a Serial or Multi-part

**NB**: A cluster may contain HT Items of multiple formats.  
**NB2**: Format as reported by members is irrelevant.

## Cluster Format ##
The Cluster Format is used in the overlap calculations. It is derived from the Item Formats of all the HT Items in the cluster, although it may not and often won't match all of the HT Item formats.

**Multi-part Monograph**
: Any of the HT Items in the cluster are MPMs.

**SER / SPM**
: Is not MPM. One or more of the HT Items in the cluster are SPM _and_ one or more of the HT Items in the cluster are SER.

**SER**
: Is not MPM or SER/SPM. Any of the HT Items in the cluster are SER (and by implication ALL are SER).

**SPM**
: Is not MPM, SER/SPM, or SER.

## Cost Allocation ##

**Public Domain vs In-Copyright**
: For cost allocation purposes, HT Items with access "allow" in the Hathifiles are considered "public domain" and access "deny" are considered "in copyright". Rationale for the "allow" and "deny" found in the Hathifiles is underdefined. 

**Target Cost**
: Set by the Board and Executive Director. Portion of the budget to be paid for by HT Item allocations.

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
: The IC Costs assigned to Hathitrust / Number of members found in the `ht_billing_members` table that aren't Hathitrust. Hathitrust has IC costs due to being the billing entity for some HT Items. This redistributes these costs across the membership.

**HScore**
: A share of an HT Item. The share is the inverse of the number of members who report holding the item.

**Total HScore (for Member)**
: Sum of HScores for Member for each of SPM, MPM and SER

**Total IC Cost for Member**
: Total HScore for Member * Cost Per Volume

**Total Cost for Member**
: Total IC Cost for Member + Total PD Cost for Member + Extra Per Member


## HT Item Overlap ##
Determining who holds a particular in-copyright HT Item.

For HT Items in **clusters** that are not MPM, all organizations with a holding in the cluster and the billing entity for the HT Item are allocated a share. 

For HT Items in **clusters** that are MPM, the process is more complicated. Organizations with holdings:
- Organizations with holdings with empty **n_enum**. The reverse is **not** true; i.e. Items with empty n_enum don't match everything.
- Organizations with holdings with an **n_enum** matching the **n_enum** of the Item.
- Organizations with **holdings** in the cluster with **n_enum** that don't match any of the **n_enum** found in any of the HT Items in the cluster. [^2]
- Billing entity for the HT Item.

**NB**: Billing entities apply only to the HT Item they are on. For example, a billing entity on an HT Item with an empty n_enum will **not** match other HT Items in the cluster.

## Frequency Table ##
HT Item HScores are held in a frequency table separated by member and **HT Item** format.[^3] This gets compiled into per format per member cost allocations. 

[^1]: System only uses n_enum which is likely wrong, but n_chron and n_enum_chron exist so changes should be easy.

[^2]: This can lead to cases where a member providing more data or HT ingesting more HT Items can reduce access/cost.

[^3]: Implementation detail: `<member> => <format> : <num of orgs that hold a thing> : <frequency>`
Total hscore for a particular member and format is thus  ∑(1 / number of orgs * frequency). This doubles as a data structure for overlap histograms which is why it is more complicated than it needs to be for only cost allocation.
