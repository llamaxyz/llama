# Strategy Comparison

Below is a table comparing the key features of the strategy logic contracts.

## Key Concepts

- **Threshold:** `Relative` if the (dis)approval threshold is a relative percentage of the supply and `Absolute` if it's an absolute value.
- **Supply:** This only matters for relative strategies. It is the number that the minimum percentage is multiplied by to arrive at the threshold. This can be the total quantity of the (dis)approval role at action creation or the total number of role holders at action creation.
- **Policyholder weight**: The weight of an eligible policyholder's cast. This is either hardcoded to 1 or the policyholder's role quantity.

## Comparison Table

| Name                                 | Threshold | Action creator can cast? | Policyholder weight | Supply              |
| ------------------------------------ | --------- | ------------------------ | ------------------- | ------------------- |
| LlamaRelativeQuantityQuorum          | Relative  | ✅                        | Role quantity       | Total role quantity |
| LlamaRelativeHolderQuorum            | Relative  | ✅                        | Role quantity       | Total role holders  |
| LlamaRelativeUniqueHolderQuorum      | Relative  | ✅                        | 1                   | Total role holders  |
| LlamaAbsoluteQuorum                  | Absolute  | ✅                        | Role quantity       | —                   |
| LlamaAbsolutePeerReview              | Absolute  | ❌                        | Role quantity       | —                   |
