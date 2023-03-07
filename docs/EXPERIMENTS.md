# Experiments

This framework allows us to develop and test experimental features with different build configurations in release and debug builds. The framework also supports more advanced experimentation with AB testing, using the Experimentation Platform (ExPlat) in the Tracks library.

## Dependencies

- `Automattic-Tracks-iOS` library: integrates the ExPlat service for AB testing.

## Public interfaces

- Enum `FeatureFlag`: where we define feature flag cases for all the experimental features
- Protocol `FeatureFlagService` and default implementation `DefaultFeatureFlagService`. The protocol allows mocking feature flag states in unit tests, and the default implementation is based on build configurations
- Enum `BuildConfiguration`: the current build configuration `BuildConfiguration.current` is currently used in logging
- Enum `ABTest`: where we define experiment cases for A/B testing

## Build configurations

The project has three build configurations to match the WooCommerce app: `Debug`, `Release`, and `Release-Alpha`. The `BuildConfiguration` enum is then based on the build configuration via the Experiments project build settings > `Active Compilation Conditions`:

- `Debug` build configuration: `DEBUG` value is set. Used for debug builds from Xcode
- `Release` build configuration: no values are set. Used for release builds for the App Store
- `Release-Alpha` build configuration: `ALPHA` value is set. Used for one-off installable builds for internal testing, which we can trigger from a commit in a pull request

In the default implementation of `FeatureFlagService`, some of the feature flags are based on build configurations - enabled in `Debug` and `Release-Alpha` configurations, and disabled in `Release` builds.

## Run an A/B test

To add an ExPlat experiment to the app, add a new case to the `ABTest` enum in the `Experiments` framework.

Define the experiment context (`loggedOut` or `loggedIn`) in `ABTest`, depending on whether the experience being experimented on occurs in the logged-out or logged-in context. This determines whether the test assignment prioritizes the `anonid` (for logged-out experiments) or `userid` (for logged-in experiments).

Once the experiment is added to the app, define the behavior for each variation (this must be in the context specified above):

```
if ABTest.experimentName.variation == .control {
    // Control logic
} else {
    // Treatment logic
}
```
### Experiment Design Considerations

If your experiment uses an exposure event, watch out for race conditions between the exposure event and the test assignment or experiment metrics. The exposure event must be triggered _after_ the app receives the test assignment from the experiments endpoint, and _before_ any of the experiment metrics are triggered.

Due to potential race conditions, do not use these as exposure events:

- `woocommerceios_application_opened`
- `woocommerceios_application_installed`

When designing a logged-out experiment, consider that you may not need an exposure event at all.
