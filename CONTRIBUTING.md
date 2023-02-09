# Contribution guide

NOTE: This format should only be followed after your PR gets approved and you are squashing your commits to merge to main.

## Vertex Development

Please consider these guidelines when filing a pull request:

*  Please write tests.
*  After your PR gets approved, you should squash your commits when merging to main, and follow the convention below.

## Final Commit Message Format

Commit message consists of a **header**, a **body** and a **footer**.  The header has a special
format that includes a **type**, a **scope**, **subject**, and should also include the PR number in parenthesis:

```
feat(Buttons): Added Button Groups (#622)
<BLANK LINE>
<body>
<BLANK LINE>
<optional footer>
```

The **header** is mandatory and the **scope** of the header is optional.

The **body** should contain the motivation, that's where you describe the context of the change, the history how the code relates to other code, what the problem is and why it is a problem. That should be followed by describing the changes the commit actually makes. Do not focus too much on how the code works as that is better described as source code comments in the patch itself (to the extend that your code needs to be explained). Rather focus on the change itself.

Finally, describe what effects the change will have. Sometimes this is trivial, like a bug that was described in the motivation is now fixed.

### Example

An example of a fix commit would look like this:
```
fix: Remove semicolon from N4CC's set of wrappable chars (#201)

**Motivation:**

The comment above `ShouldWrapCharsBitSet` suggests that semicolons are legal
according to Netty 4's encoder and decoder, but they are not.

**Modifications:**

Remove the semicolon character from the bit set.

**Result:**

Now the bit set is correctly aligned with Netty 4's strict validation rules and
the comment is correct. There is no difference in behavior since validation
happens after unwrapping: a semicolon in a cookie value will cause the
validation to fail regardless of whether the value is wrapped.
```
Another example would be of an feature that contains a breaking change:
```
feat: Introduce `.withDeadlines` API for admission control (#228)

**Motivation:**

We would like deadline admission control to be turned on by default.

**Modifications:**

Introduce new APIs so that servers can be configured with
`Server.withAdmissionControl.deadlines` to turn deadlines on,
`.darkModeDeadlines` to turn deadlines on in dark mode, and `.noDeadlines` so
that `DeadlineFilter` can be turned on off. We also introduce more params for
configuring `DeadlineFilter`'s window for when `DeadlineFilter` is enabled or in
dark mode.

**Result:**

BREAKING CHANGE: Rename DeadlineFilter.Param(maxRejectFraction) to
DeadlineFilter.MaxRejectFraction(maxRejectFraction) to reduce confusion
when adding additional params.
```

### Type
Must be one of the following:

* **feat**: A new feature
* **fix**: A bug fix
* **docs**: Documentation only changes
* **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing
  semi-colons, etc)
* **refactor**: A code change that neither fixes a bug nor adds a feature
* **perf**: A code change that improves performance
* **test**: Adding missing or correcting existing tests
* **chore**: Changes to the build process or auxiliary tools and libraries such as documentation
  generation
