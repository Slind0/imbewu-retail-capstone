# Imbewu Retail Data Dictionary

## Purpose

This data dictionary documents the six source tables used for the
**Imbewu Investigation** capstone. It describes the dataset structure,
analytical use of each field, and the data-quality issues and treatment
decisions identified during the investigation.

The source data covers transactions from **January 2024 to June 2025**
across **45 stores**.

------------------------------------------------------------------------

## 1. customers

**Purpose:** Contains customer demographic and loyalty information used
for customer-segment analysis.

  -----------------------------------------------------------------------
  Column            Data Type         Description       Data Quality /
                                                        Treatment Notes
  ----------------- ----------------- ----------------- -----------------
  `customer_id`     Text              Unique identifier Primary key; no
                                      for each customer duplicate
                                                        customer IDs
                                                        identified

  `first_name`      Text              Customer first    Retained as
                                      name              supplied

  `last_name`       Text              Customer surname  Retained as
                                                        supplied

  `gender`          Text              Customer gender   139 missing
                                                        values
                                                        (approximately
                                                        4.6%)

  `birth_year`      Whole Number      Customer year of  161 missing
                                      birth             values
                                                        (approximately
                                                        5.4%)

  `loyalty_tier`    Text              Customer loyalty  Values include
                                      tier              Bronze, Silver
                                                        and Gold

  `home_suburb`     Text              Customer home     Retained as
                                      suburb            supplied

  `signup_date`     Date              Date the customer Used as a date
                                      joined /          field
                                      registered        
  -----------------------------------------------------------------------

### Data-quality decisions

Missing `gender` and `birth_year` values were retained because these
fields were not required to validate the underlying sales transactions.
The customer table contains 3,000 customer records.

------------------------------------------------------------------------

## 2. products

**Purpose:** Contains the product master data used to analyse sales by
product, brand, category and sub-category.

  -----------------------------------------------------------------------
  Column            Data Type         Description       Data Quality /
                                                        Treatment Notes
  ----------------- ----------------- ----------------- -----------------
  `product_id`      Text              Unique product    Primary key; no
                                      identifier        duplicate product
                                                        IDs identified

  `product_name`    Text              Product           Retained as
                                      description /     supplied
                                      name              

  `category`        Text              Main product      Five main
                                      category          categories
                                                        identified

  `sub_category`    Text              Product           Used for more
                                      sub-category      detailed product
                                                        analysis

  `brand`           Text              Product brand     Retained as
                                                        supplied

  `unit_cost`       Decimal Number    Recorded unit     Converted to
                                      cost of the       decimal number
                                      product           

  `unit_price`      Decimal Number    Standard unit     Converted to
                                      selling price     decimal number;
                                                        not used as the
                                                        actual
                                                        transaction
                                                        revenue value
  -----------------------------------------------------------------------

### Data-quality decisions

The product table contains 48 products. For revenue calculations,
`unit_price_at_sale` from `transaction_items` was used rather than the
standard `unit_price`, because it reflects the price actually charged
during the transaction.

------------------------------------------------------------------------

## 3. promotions

**Purpose:** Contains details of promotional campaigns, including the
targeted category, campaign dates and discount percentage.

  ---------------------------------------------------------------------------
  Column                Data Type         Description       Data Quality /
                                                            Treatment Notes
  --------------------- ----------------- ----------------- -----------------
  `promo_id`            Text              Unique promotion  Four promotion
                                          identifier        records

  `promo_name`          Text              Name of the       Includes Pap
                                          promotion         Power Promo

  `category_targeted`   Text              Category or       Used to
                                          product group     understand
                                          targeted by the   promotion scope
                                          promotion         

  `start_date`          Date              Promotion start   Converted to Date
                                          date              

  `end_date`            Date              Promotion end     Converted to Date
                                          date              

  `discount_pct`        Percentage        Promotional       Source values
                                          discount          represented
                                          percentage        percentages as
                                                            whole numbers and
                                                            were converted
                                                            appropriately for
                                                            reporting
  ---------------------------------------------------------------------------

### Data-quality decisions

The promotion table contains four campaigns. Promotion dates were
converted to Date data type. Percentage values should be interpreted
carefully to avoid multiplying the displayed percentage by 100 twice.

------------------------------------------------------------------------

## 4. stores

**Purpose:** Contains store attributes used for provincial, store-format
and individual-store performance analysis.

  -----------------------------------------------------------------------
  Column            Data Type         Description       Data Quality /
                                                        Treatment Notes
  ----------------- ----------------- ----------------- -----------------
  `store_id`        Text              Unique store      Primary key; no
                                      identifier        duplicate store
                                                        IDs identified

  `store_name`      Text              Store trading     Used for
                                      name              store-level
                                                        investigation

  `format`          Text              Store format      Express, Market
                                                        or Mega

  `province`        Text              Province in which Inconsistent
                                      the store         capitalisation
                                      operates          identified and
                                                        standardised

  `city`            Text              Store city        Retained as
                                                        supplied

  `suburb`          Text              Store suburb      Retained as
                                                        supplied

  `store_manager`   Text              Store manager     One missing value
                                                        identified

  `opened_date`     Date              Store opening     Used as a date
                                      date              field
  -----------------------------------------------------------------------

### Data-quality decisions

The table contains 45 stores. Province values contained inconsistent
capitalisation, including `Western Cape` / `western cape` and `Gauteng`
/ `gauteng`. These were standardised before analysis. After cleaning,
Western Cape contains 12 stores.

------------------------------------------------------------------------

## 5. transactions

**Purpose:** Contains transaction-header information and links each
transaction to a store, customer (where available), transaction date and
payment method.

  --------------------------------------------------------------------------
  Column               Data Type         Description       Data Quality /
                                                           Treatment Notes
  -------------------- ----------------- ----------------- -----------------
  `transaction_id`     Text              Unique            Primary key; no
                                         transaction       duplicate
                                         identifier        transaction IDs
                                                           identified

  `store_id`           Text              Store where the   All store IDs
                                         transaction       matched the
                                         occurred          stores table

  `customer_id`        Text              Customer linked   3,911 null values
                                         to the            (approximately
                                         transaction       42.7%)

  `transaction_date`   Date              Date on which the Source included
                                         transaction       time; converted
                                         occurred          to Date for the
                                                           Power BI calendar
                                                           relationship

  `payment_method`     Text              Payment method    Values include
                                         used              Card, Cash, EFT
                                                           and SnapScan
  --------------------------------------------------------------------------

### Data-quality decisions

The table contains 9,164 transactions covering **1 January 2024 to 30
June 2025**.

Transactions with a null `customer_id` were retained because they are
valid sales records. For customer-segment analysis, these transactions
were classified as **Unidentified**. This label does **not** imply that
the customers were definitely non-loyalty customers; the source data
does not explain why the customer identifier is missing.

The original transaction timestamp included both date and time. For
Power BI time-intelligence calculations, it was converted to Date so it
could relate correctly to the Date table at daily grain.

------------------------------------------------------------------------

## 6. transaction_items

**Purpose:** Contains the individual products and quantities within each
transaction and is the main fact table used to calculate sales revenue
and units sold.

  ------------------------------------------------------------------------------------
  Column                 Data Type         Description        Data Quality / Treatment
                                                              Notes
  ---------------------- ----------------- ------------------ ------------------------
  `item_id`              Text              Unique             Primary key; no
                                           transaction-line   duplicate item IDs
                                           identifier         identified

  `transaction_id`       Text              Transaction        All IDs matched the
                                           associated with    transactions table
                                           the line item      

  `product_id`           Text              Product purchased  All IDs matched the
                                                              products table

  `quantity`             Whole Number      Number of units    Observed values ranged
                                           purchased          from 1 to 6

  `unit_price_at_sale`   Decimal Number    Actual unit price  Used in the revenue
                                           charged at the     calculation
                                           time of sale       

  `discount_applied`     Decimal Number /  Discount recorded  Used to identify
                         Percentage        on the line item   discounted/promotional
                                                              transactions; not
                                                              deducted again from
                                                              revenue
  ------------------------------------------------------------------------------------

### Revenue calculation

Revenue was calculated as:

`Revenue = quantity × unit_price_at_sale`

`discount_applied` was **not subtracted again**, because
`unit_price_at_sale` already represents the actual selling price
recorded for the transaction.

The table contains 48,641 transaction-item records.

------------------------------------------------------------------------

## 7. Key Relationships

The analytical model uses the following primary relationships:

  ---------------------------------------------------------------------------------------------
  Parent Table     Key                Child Table           Key                  Relationship
  ---------------- ------------------ --------------------- -------------------- --------------
  `stores`         `store_id`         `transactions`        `store_id`           One-to-many

  `customers`      `customer_id`      `transactions`        `customer_id`        One-to-many

  `transactions`   `transaction_id`   `transaction_items`   `transaction_id`     One-to-many

  `products`       `product_id`       `transaction_items`   `product_id`         One-to-many

  `Date`           `Date`             `transactions`        `transaction_date`   One-to-many
  ---------------------------------------------------------------------------------------------

`promotions` is maintained separately because the supplied promotion
data does not contain a direct transaction-level promotion key.

------------------------------------------------------------------------

## 8. Key Data-Quality Findings and Analytical Decisions

1.  **No exact duplicate rows** were identified in the six source tables
    during profiling.
2.  Primary identifiers (`store_id`, `product_id`, `customer_id`,
    `transaction_id` and `item_id`) were unique in their respective
    tables.
3.  Referential-integrity checks did not identify unmatched store IDs,
    product IDs or transaction IDs in the main transactional
    relationships.
4.  Province names were standardised because of inconsistent
    capitalisation.
5.  Transactions with missing `customer_id` values were retained and
    labelled **Unidentified** only for customer-segment reporting.
6.  Missing customer demographic values were retained rather than
    deleting otherwise valid customer records.
7.  Transaction timestamps were converted to Date for the Power BI
    Date-table relationship and YoY calculations.
8.  Revenue was calculated using `quantity × unit_price_at_sale`.
9.  `discount_applied` was not deducted from revenue a second time.
10. Comparable year-on-year analysis used **January--June 2025 versus
    January--June 2024**, because the dataset ends in June 2025.
11. Store-level analysis was used to avoid treating Western Cape as a
    single homogeneous group.
12. Transaction count was treated as the number of completed purchases,
    **not as a direct measure of store foot traffic**.

------------------------------------------------------------------------

## 9. Analytical Notes

The cleaned data model supports the main investigation areas used in the
capstone:

-   Western Cape versus other provinces.
-   Individual Western Cape store performance.
-   Transaction volume and average basket behaviour.
-   Units and items per basket.
-   Product and category performance.
-   Customer loyalty-tier performance.
-   Promotion analysis, including the April 2025 Pap Power Promo.

All cleaning and interpretation decisions above were retained to ensure
the analysis remained reproducible and transparent.
