# Strategy Comparison

Below is a table comparing the key features of the strategy logic contracts.

## Key Concepts

- **Threshold:** Is the (dis)approval threshold an absolute value or is it a relative percentage of the supply?
- **Supply:** For relative strategies, what is the minimum percentage multiplied by to arrive at the threshold? This can be the total quantity of the (dis)approval role at action creation or the total number of role holders at action creation time.
- **Policyholder weight**: When an eligible policyholder casts, how much weight does their cast carry? This is either hardcoded to 1 or it can be their role quantity.

## Comparison Table

| Name                                 | Threshold | Action creator can cast? | Policyholder weight | Supply              |
| ------------------------------------ | --------- | ------------------------ | ------------------- | ------------------- |
| LlamaRelativeQuantityQuorum          | Relative  | ✅                        | Role quantity       | Total role quantity |
| LlamaRelativeHolderQuorum            | Relative  | ✅                        | Role quantity       | Total role holders  |
| LlamaRelativeUniqueHolderQuorum      | Relative  | ✅                        | 1                   | Total role holders  |
| LlamaAbsoluteQuorum                  | Absolute  | ✅                        | Role quantity       | —                   |
| LlamaAbsolutePeerReview              | Absolute  | ❌                        | Role quantity       | —                   |
