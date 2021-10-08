# Description of Format and Overlap Determinations #
This attempts to describe what this system actually does. This does not attempt to exhaustively describe all corner cases or emergent properties.

## Definitions ##
**Format**
: mono (spm), multi (mpm), serial (ser)

**Cluster**
: Collection of HT Items, Holdings, and Concordance pairs united by a list of OCNs determined to be equivalent.

**Bib Record**
: A preferred record from Zephir containing one or more HT Items with a single Hathitrust record ID.

**HT Item**
: Volume ID and associated metadata taken from the [Hathifiles](https://www.hathitrust.org/hathifiles).

**Print Serials List**
: List of Record Ids determined to be serials by some unknown UMich process performed by Automation, Indexing, and Metadata. List is limited to those held by UMich.

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

**Member vs Organization**
: Members are those organizations found in the ht_billing_members with "status" equal to 1. Only organizations that are members are used in the cost calculations.

**Target Cost**
: Set by the Board and Executive Director. Portion of the budget to be paid for by HT Item allocations.

**Cost Per Volume**
: Target Cost / Total Number of HT Items

**Member Weight**
: A number assigned to a member by the ED that determines their share of Public Domain costs. 

**Total Weight**
: The sum of member weights found in the `ht_billing_members` table of the holdings database. **Which process/system has ownership of this table?**
  The Executive Director assigns member weights based on a [formula](https://www.hathitrust.org/Cost) approved by the membership in 2019. The calculation for system members can be found [here](https://docs.google.com/spreadsheets/d/1C74IUynslWOSCAkdlcLO8jgRDvuXq-JcQUsyapD9JEI/edit?usp=sharing).

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
This is a description of the process by which the system determines who holds a particular in-copyright HT Item. 

For HT Items in **clusters** that are not MPM, an organization is considered to hold the HT Item and a member is allocated a share for it if either of the following are true:
- It is the billing entity for the HT Item (i.e. the depositor of an HT Item is always assumed to hold it)
- It submitted a holding that is in the cluster

For HT Items in **clusters** that are MPM, the process is more complicated. An organization is considered to hold the item and a member is allocated a share if any of the following are true:
- It is the billing entity for the HT Item.
- It has a holding in the cluster with an **n_enum** matching the **n_enum** of the HT Item.
- It has a holding in the cluster with an empty **n_enum**. The reverse is **not** true: holdings with empty n_enums match all HT Items in an MPM cluster; but HT Items with empty n_enums match only holdings with empty n_enums.
- It has holdings in the cluster, but none of the reported **n_enum** match any of the **n_enum** found in any of the HT Items in the cluster. That is, if no holdings n_enums match, then this is assumed to be a data problem, and the organization is considered to hold all of the items in the cluster. [^2]

**NB**: Billing entities apply only to the HT Item they are on. For example, a billing entity on an HT Item with an empty n_enum will **not** match other HT Items in the cluster.

## Frequency Table ##
HT Item HScores are held in a frequency table separated by member and **HT Item** format.[^3] This gets compiled into per format per member cost allocations. 

[^1]: System only uses n_enum which is likely wrong, but n_chron and n_enum_chron exist so changes should be easy.

[^2]: This can lead to cases where an organization providing more data or HT ingesting more HT Items can reduce access/cost. That is, if the organization or HT adds a record that does match, they will no longer be allocated a share of those that don't.

[^3]: Implementation detail: `<member> => <format> : <num of orgs that hold a thing> : <frequency>`
Total hscore for a particular member and format is thus  ∑(1 / number of orgs * frequency). This doubles as a data structure for overlap histograms which is why it is more complicated than it needs to be for only cost allocation.
