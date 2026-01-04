# Environment Setup Guide

This project uses environment variables to configure the build process, specifically for `xcodegen` to inject the correct Development Team ID into the Xcode project.

We use `direnv` to manage these environment variables automatically when you enter the directory.

## Prerequisites

1.  **Install direnv**:
    ```bash
    brew install direnv
    ```
    Make sure to hook `direnv` into your shell (add to `~/.zshrc` or `~/.bashrc`):
    ```bash
    eval "$(direnv hook zsh)"
    ```

2.  **Install VS Code Extension (Optional but Recommended)**:
    - [direnv](https://marketplace.visualstudio.com/items?itemName=mkhl.direnv) extension for VS Code can help the editor pick up the variables.

## Configuration Steps

1.  **Create the `.env` file**:
    Copy the example file to create your local configuration.
    ```bash
    cp .env.example .env
    ```

2.  **Edit `.env`**:
    Open `.env` and set your Apple Development Team ID.
    ```bash
    TEAM_ID=YOUR_ACTUAL_TEAM_ID
    ```
    *You can find your Team ID in the Apple Developer Portal or by running `xcodebuild -showBuildSettings` on an existing signed project.*

3.  **Setup `.envrc`**:
    Copy the example configuration.
    ```bash
    cp .envrc.example .envrc
    ```

4.  **Allow direnv**:
    In your terminal, run:
    ```bash
    direnv allow
    ```

## How it Works

- The `.envrc` file contains the command `dotenv`.
- This tells `direnv` to load variables defined in the `.env` file into your shell environment.
- When you run `xcodegen` (or when Sweetpad runs it), it will substitute `${TEAM_ID}` in `project.yml` with the value from your environment.

## Troubleshooting Sweetpad / VS Code

If Sweetpad or VS Code does not pick up the environment variables:

1.  **Restart VS Code**: Sometimes VS Code needs a restart to pick up changes from `direnv` if you launched it from a terminal.
2.  **Launch from Terminal**: Open VS Code from the terminal *after* `direnv` has loaded the variables:
    ```bash
    code .
    ```
3.  **Check Sweetpad Settings**: Ensure Sweetpad is using the correct shell or that the environment is propagated.

## Android Setup (Command Line + VS Code)

1. Install Java 17 (e.g., `brew install openjdk@17` on macOS or your distro package on Linux).
2. Install Android command-line tools and set `ANDROID_HOME` or `ANDROID_SDK_ROOT` to the SDK path.
3. Install platform tools and build-tools via `sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"`.
4. In VS Code, add the Kotlin and Gradle extensions for syntax and task integration.
5. From [android](../android), run `./gradlew tasks` to verify the toolchain.
