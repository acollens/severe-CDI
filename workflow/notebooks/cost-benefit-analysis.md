Cost-Benefit Analysis
================
2023-05-11

- use values from confusion matrix for one representative model on a
  test set. or get average precision?
  - Number needed to screen (NNS) - the number of alerted patients the
    models must flag to identify 1 true positive.
  - Number needed to treat (NNT) - the number of true positive patients
    one must treat for 1 patient to benefit from the treatment.
  - Number needed to benefit (NNB = NNS x NNT) - how many patients must
    be screened for 1 patient to benefit.
- assumptions
  - cost of a non-severe case
  - cost of a severe case
    - days in icu, colectomy
  - cost of possible treatments:
    - abx: metronizadole, vancomycin, fidaxomycin
    - fmt, bezlotoxumab (monoclonal antibodies)

## evaluating ml models

[number needed to
benefit](https://academic.oup.com/jamia/article-abstract/26/12/1655/5516459)

- Number needed to screen (NNS) - the number of alerted patients the
  models must flag to identify 1 true positive.
- Number needed to treat (NNT) - the number of true positive patients
  one must treat for 1 patient to benefit from the treatment.
- Number needed to benefit (NNB = NNS x NNT) - how many patients must be
  screened for 1 patient to benefit.

> In the simplest terms, prediction can be distilled into an NNS and
> action into a number needed to treat. When contextualized within this
> framework, the product of NNS and number needed to treat results in a
> number needed to benefit. The table outlines key variables in this
> framework that will alter the estimated number needed to benefit
> across different modeling and implementation scenarios.

## treatment options & costs

- Vince: consider bezlotoxumab since it targets the toxin, mouse models
  show it reduces organ damage.
- Krishna: bezlotoxumab clinical trials didn’t find signal for limiting
  severity. however fidaxomicin is superior to vancomycin for cure and
  time to resolution of diarrhea ([IDSA 2021
  update](https://doi.org/10.1093/cid/ciab549)).

### [Gupta *et al.* 2021 - Economic Burden of CDI](https://journals.sagepub.com/doi/10.1177/17562848211018654)

- average cost of CDI case in the US:
  - \$8k to \$30k (Nanwa *et al*)
  - \$21k (Zhang *et al*)
  - likely underestimates of true attributable costs.
- treatment
  - IDSA recommends either vancomycin or fidaxomycin for 10 days
  - Metronizadole out of favor, not efficacious
  - Recommend FMT after multiple recurrences
  - monoclonal Ab now an fda-approved treatment

#### treatment costs

> More recently, Rajasingham et al. calculated the costs of the
> currently available therapies for CDI. The cost of oral metronidazole
> (10-day course) ranged from US\$4.38 to US\$13.14, intravenous
> metronidazole (14-day course) from US\$19.56 to \$58.68, vancomycin
> (10-day course) from US\$7.04 to US\$21.12, rifaximin (20-day course)
> from US\$44.16 to US\$132.48, and fidaxomicin (10day course), being
> the most expensive option, ranged from US\$883.60 to US\$2650.80. It
> is difficult to predict the exact cost of FMT due to the multiple
> variables involved, including source of stool and route of
> administration. In general, one course of FMT is estimated to cost
> between US\$500 and US\$2000.