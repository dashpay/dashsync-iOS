# Contributing

Thank you for your interest in contributing to DashSync-iOS! Before
contributing, it may be helpful to understand the goal of the project. The goal
of DashSync-iOS is to develop a light client that can both connect to the Dash 
Core Network and support Dash Platform features. While all contributions are
welcome, contributors should bear this goal in mind in deciding if they should
target the main  DashSync-iOS project or a potential fork. When targeting the
main DashSync-iOS project, the following process leads to the best chance of
landing changes in master.

All work on the code base should be motivated by a [Github
Issue](https://github.com/dashevo/dashsync-iOS/issues).
[Search](https://github.com/dashevo/dashsync-iOS/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22)
is a good place start when looking for places to contribute. If you
would like to work on an issue which already exists, please indicate so
by leaving a comment.

All new contributions should start with a [Github
Issue](https://github.com/tendermint/tendermint/issues/new/choose). The
issue helps capture the problem you're trying to solve and allows for
early feedback. Once the issue is created the process can proceed in different
directions depending on how well defined the problem and potential
solution are. If the change is simple and well understood, maintainers
will indicate their support with a heartfelt emoji.

When the problem is well understood but the solution leads to large
structural changes to the code base and potentially the protocol itself, these changes should be proposed in
the form of an [Dash Improvement Proposal](https://github.com/dashpay/dips). The DIP will help build consensus on an
overall strategy to ensure the code base maintains coherence
in the larger context. If you are not comfortable with writing a DIP,
you can open a less-formal issue and the maintainers might help you
turn it into an DIP.

When the problem as well as proposed solution are well understood,
changes should start with a [draft
pull request](https://github.blog/2019-02-14-introducing-draft-pull-requests/)
against master. The draft signals that work is underway. When the work
is ready for feedback, hitting "Ready for Review" will signal to the
maintainers to take a look.

![Contributing flow](./docs/imgs/contributing.png)

Each stage of the process is aimed at creating feedback cycles which align contributors and maintainers to make sure:

- Contributors don’t waste their time implementing/proposing features which won’t land in master.
- Maintainers have the necessary context in order to support and review contributions.

## Dependencies

We use [cocoapods](https://cocoapods.org/) to manage dependencies.

Inside the DashSync repository there is a [podfile](Podfile) that should used to add a dependency.

To install dependencies open the terminal, go to the root of the project and run `pod install`. To update run `pod update`.
