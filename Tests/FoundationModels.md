# Monthly Tips Hemat

Totals, category distribution, budget comparison and AI context use the current calendar month, from its first day through now. Previous-month and future expenses are excluded. Daily average equals month-to-date recorded total divided by elapsed calendar days, not only days containing transactions. Budget-to-date is daily budget multiplied by the same elapsed-day count. Missing-day coverage remains explicit in details.

The header says Pengeluaran bulan ini and the category section says Kategori bulan ini. The period starts on the first of the month and resets automatically at a new month. Cache keys include the month start, elapsed day count and current-month data, so prior-month edits do not trigger model generation.

Suggestions stay inside details, generate automatically, use the supported model language without translation and reuse valid cached advice for unchanged data. A small accessible spinner replaces loading text; source labels are hidden. Error handling continues through one root toast with duplicate automatic errors suppressed.

Run `bash Tests/run-regressions.sh`. Calendar tests include month boundaries, an empty new month, first-day denominator, leap-year February, previous-month cache isolation, budget thresholds and invalid inputs. Physical iPhone layout and offline behavior still require device validation.
