# Setup a New Mac (Manual Installation - not Homebrew)

This guide outlines how to install common development software on a new Mac by downloading binaries directly, without using package managers like Homebrew.  If you have Homebrew you can use that, but not everyone is allowed to install Xcode.

## Install Python

The standard "manual" method for Python on macOS is to use the official installer, which correctly handles framework setup and pathing.

1.  Download the latest macOS installer from the official Python website: [https://www.python.org/downloads/macos/](https://www.python.org/downloads/macos/)
2.  Run the downloaded `.pkg` file and follow the installation prompts. The installer will place the binaries in `/usr/local/bin`.
3.  The installer typically offers to update your shell profile for you. If you need to do it manually, edit your shell's configuration file (`~/.zshrc` for modern macOS, or `~/.bash_profile` for bash).
4.  Add the directory (not the file) to your `PATH` and create a convenient alias.

    ```bash
    # Setting PATH for Python
    # This line should point to the directory containing the executables
    PATH="/usr/local/bin:${PATH}"
    export PATH

    # Alias to use 'python' for 'python3'
    alias python='python3'
    ```
5.  Restart your terminal or run `source ~/.zshrc` for the changes to take effect.

## Install JQ

1.  Download the `jq` executable for macOS from the official site: [https://jqlang.github.io/jq/download/](https://jqlang.github.io/jq/download/)
2.  Open your Terminal and run the following commands to make the binary executable, remove the macOS quarantine attribute, and move it into your path.

    ```bash
    # Navigate to your downloads folder
    cd ~/Downloads

    # Make the file executable
    chmod +x ./jq-macos-arm64

    # Optional: Remove Apple's quarantine attribute that can block execution
    xattr -d com.apple.quarantine ./jq-macos-arm64

    # Move the binary to a location in your PATH and rename it to 'jq'
    sudo mv ./jq-macos-arm64 /usr/local/bin/jq
    ```

## Install Google Cloud SDK (gcloud)

1.  Download the SDK archive from the official documentation: [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install) (choose the correct version, e.g., macOS ARM 64-bit).
2.  Extract the archive. This will create a folder named `google-cloud-sdk`.
3.  Move the extracted `google-cloud-sdk` folder to a permanent location, such as your home directory.
    ```bash
    # Example: move from Downloads to your home directory
    mv ~/Downloads/google-cloud-sdk ~/
    ```
4.  Run the installation script from inside the SDK directory and follow the prompts.
    ```bash
    ~/google-cloud-sdk/install.sh
    ```
    > The script will guide you through updating your `PATH` and enabling shell command completion.

## Install Terraform

1.  Download the correct Terraform binary from the HashiCorp website: [https://developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)
    > **Note:** For modern Macs with Apple Silicon (M1, M2, M3), be sure to download the **ARM64** version.
2.  Unzip the downloaded file, which will extract a single `terraform` executable.
3.  Move the `terraform` binary to `/usr/local/bin` to make it accessible from anywhere in your terminal.
    ```bash
    # Navigate to your downloads folder
    cd ~/Downloads

    # Unzip the archive (the filename may vary)
    unzip terraform_*_darwin_arm64.zip

    # Move the binary into your PATH
    sudo mv terraform /usr/local/bin/terraform
    ```

## Install Visual Studio Code

1.  Download the VS Code application from the official website: [https://code.visualstudio.com/download](https://code.visualstudio.com/download)
2.  Open your `Downloads` folder in Finder.
3.  Drag the `Visual Studio Code.app` file and drop it into your `Applications` folder.