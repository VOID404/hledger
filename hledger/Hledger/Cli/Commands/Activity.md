## activity

Show an ascii barchart of posting counts per interval.

_FLAGS

The activity command displays an ascii histogram showing transaction
counts by day, week, month or other reporting interval (by day is the
default). With query arguments, it counts only matched transactions.

Examples:
```shell
$ hledger activity --quarterly
2008-01-01 **
2008-04-01 *******
2008-07-01 
2008-10-01 **
```
