## close

(equity)

Generate transactions which transfer account balances to and/or from
another account (typically equity).
This can be useful for migrating balances to a new journal file, 
or for merging earnings into equity at end of accounting period.

By default, it prints a transaction that zeroes out ALE accounts
(asset, liability, equity accounts; this requires account types to be configured);
or if ACCTQUERY is provided, the accounts matched by that.

*(experimental)*

_FLAGS

This command has four main modes, corresponding to the most common use cases:

1. With `--close` (default), it prints a "closing balances" transaction
that zeroes out ALE (asset, liability, equity) accounts by default
(this requires [account types](hledger.md#account-types) to be inferred or declared);
or, the accounts matched by the provided ACCTQUERY arguments.

2. With `--open`, it prints an opposite "opening balances" transaction that restores
those balances from zero. This is similar to Ledger's equity command.

3. With `--migrate`, it prints both the closing and opening transactions.
This is the preferred way to migrate balances to a new file:
run `hledger close --migrate`, 
add the closing transaction at the end of the old file, and
add the opening transaction at the start of the new file.
The matching closing/opening transactions cancel each other out,
preserving correct balances during multi-file reporting.

4. With `--retain`, it prints a "retain earnings" transaction that transfers
RX (revenue and expense) balances to `equity:retained earnings`.
Businesses traditionally do this at the end of each accounting period;
it is less necessary with computer-based accounting, but it could still be useful
if you want to see the accounting equation (A=L+E) satisfied.

In all modes, the defaults can be overridden:

- the transaction descriptions can be changed with `--close-desc=DESC` and `--open-desc=DESC`
- the account to transfer to/from can be changed with `--close-acct=ACCT` and `--open-acct=ACCT`
- the accounts to be closed/opened can be changed with `ACCTQUERY` (account query arguments).

By default just one destination/source posting will be used, with its amount left implicit.
With `--x/--explicit`, the amount will be shown explicitly,
and if it involves multiple commodities, a separate posting will be generated for each of them
(similar to `print -x`).

With `--show-costs`, any amount costs are shown, with separate postings for each cost.
This is currently the best way to view investment lots.
If you have many currency conversion or investment transactions, it can generate very large journal entries.

With `--interleaved`, each individual transfer is shown with source
and destination postings next to each other.
This could be useful for troubleshooting.

The default closing date is yesterday, or the journal's end date, whichever is later.
You can change this by specifying a [report end date](#report-start--end-date);
(The report start date does not matter.)
The last day of the report period will be the closing date;
eg `-e 2022` means "close on 2022-12-31".
The opening date is always the day after the closing date.

### close and balance assertions

Balance assertions will be generated, verifying that the accounts have been reset to zero
(and then restored to their previous balances, if there is an opening transaction).

These provide useful error checking, but you can ignore them temporarily with `-I`,
or remove them if you prefer.

You probably should avoid filtering transactions by status or realness
(`-C`, `-R`, `status:`), or generating postings (`--auto`),
with this command, since the balance assertions would depend on these.

Note custom posting dates spanning the file boundary will disrupt the balance assertions:

```journal
2023-12-30 a purchase made in december, cleared in january
    expenses:food          5
    assets:bank:checking  -5  ; date: 2023-01-02
```

To solve that you can transfer the money to and from a temporary account,
in effect splitting the multi-day transaction into two single-day transactions:

```journal
; in 2022.journal:
2022-12-30 a purchase made in december, cleared in january
    expenses:food          5
    equity:pending        -5

; in 2023.journal:
2023-01-02 last year's transaction cleared
    equity:pending         5 = 0
    assets:bank:checking  -5
```

### Example: retain earnings

<!-- XXX update -->

Record 2022's revenues/expenses as retained earnings on 2022-12-31,
appending the generated transaction to the journal:
 
```shell
$ hledger close --retain -f 2022.journal -p 2022 >> 2022.journal
```

Note 2022's income statement will now show only zeroes,
because revenues and expenses have been moved entirely to equity.
To see them again, you could exclude the retain transaction:
```shell
$ hledger -f 2022.journal is not:desc:'retain earnings'
```

### Example: migrate balances to a new file

Close assets/liabilities/equity on 2022-12-31 and re-open them on 2023-01-01:

```shell
$ hledger close --migrate -f 2022.journal -p 2022
# copy/paste the closing transaction to the end of 2022.journal
# copy/paste the opening transaction to the start of 2023.journal
```

<!--
Or, you can automate more by generating one transaction at a time:

```shell
$ hledger close --close -f 2022.journal -p 2022 >> 2023.journal  # do this one first
$ hledger close --open  -f 2022.journal -p 2022 >> 2022.journal
```
-->

Now 2022's balance sheet will show only zeroes, indicating a balanced accounting equation.
([Unless](/investments.html#a-more-correct-entry) you are using @/@@ notation - in that case, try adding --infer-equity.)
To see the end-of-year balances again, you could exclude the closing transaction:
```shell
$ hledger -f 2022.journal bs not:desc:'closing balances'
```

### Example: excluding closing/opening transactions

When combining many files for multi-year reports, 
the closing/opening transactions cause some noise in transaction-oriented reports like `print` and `register`.
You can exclude them as shown above, but `not:desc:...` is not ideal
as it depends on consistent descriptions; also you will want to avoid excluding
the very first opening transaction, which could be awkward. 
Here is one alternative, using tags:

Add `clopen:` tags to all opening/closing balances transactions except the first,
like this:

```journal
; 2021.journal
2021-06-01 first opening balances
...
2021-12-31 closing balances  ; clopen:2022
...
```

```journal
; 2022.journal
2022-01-01 opening balances  ; clopen:2022
...
2022-12-31 closing balances  ; clopen:2023
...
```
```journal
; 2023.journal
2023-01-01 opening balances  ; clopen:2023
...
```

Now, assuming a combined journal like:

```journal
; all.journal
include 2021.journal
include 2022.journal
include 2023.journal
```

The `clopen:` tag can exclude all but the first opening transaction.
To show a clean multi-year checking register:
```shell
$ hledger -f all.journal areg checking not:tag:clopen
```

And the year values allow more precision.
To show 2022's year-end balance sheet:
```shell
$ hledger -f all.journal bs -e2023 not:tag:clopen=2023
```
