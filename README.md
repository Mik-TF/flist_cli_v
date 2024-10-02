<h1> Flist CLI in Vlang </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Building and Installing](#building-and-installing)
  - [Rebuild Locally](#rebuild-locally)
- [Usage](#usage)
- [OS-Specific Instructions](#os-specific-instructions)
  - [Windows](#windows)
  - [macOS and Linux](#macos-and-linux)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Introduction

Flist CLI is a tool that turns Dockerfiles and Docker images directly into Flist on the TF Flist Hub, passing through Docker Hub.

## Installation

### Prerequisites

- [V programming language](https://vlang.io/) (latest version) installed on your system
- Docker installed and running
- Docker Hub account
- TF Hub account and token

### Building and Installing

1. Clone this repository, build the project, run the install command and set the CLI to your path:
   ```
   git clone https://github.com/yourusername/flist-cli.git
   cd flist-cli
   v -o flist .
   sudo ./flist install
   ```

   This will copy the `flist` executable to the appropriate system location.

### Rebuild Locally

You can use the Makefile command to uninstall and reinstall the binary:

```
make build
```

## Usage

After installation, you can use the `flist` command followed by various subcommands:

```
flist <command> [arguments]
```

Available commands:
- `install`: Install the Flist CLI
- `uninstall`: Uninstall the Flist CLI
- `login`: Log in to Docker Hub and save the Flist Hub token
- `logout`: Log out of Docker Hub and remove the Flist Hub token
- `push <image>:<tag>`: Build and push a Docker image, then convert and push it as an flist
- `delete <flist_name>`: Delete an flist from Flist Hub
- `rename <flist_name> <new_flist_name>`: Rename an flist in Flist Hub
- `help`: Display help information

## OS-Specific Instructions

### Windows

1. Run Command Prompt or PowerShell as Administrator.
2. Ensure Docker Desktop is installed and running.
3. Use a Docker-enabled terminal for all Docker-related commands.
4. The `flist` executable will be installed to:
   ```
   C:\Program Files\flist\flist.exe
   ```

### macOS and Linux

1. Ensure Docker is installed and the Docker daemon is running.
2. The `flist` executable will be installed to:
   ```
   /usr/local/bin/flist
   ```
3. You may need to use `sudo` for installation and certain operations:
   ```
   sudo ./flist install
   sudo flist uninstall
   sudo flist <command>
   ```

## Troubleshooting

- If you encounter permission issues, ensure you're running the command with appropriate privileges (e.g., as administrator on Windows or with `sudo` on Unix-like systems).
- Make sure Docker is running before using Flist CLI commands.
- If you face issues with Docker commands, try logging out and logging back in to refresh your Docker credentials.
- If you encounter compilation errors, ensure you have the latest version of V installed.

## Development

To modify the Flist CLI:

1. Make your changes to the `flist.v` file.
2. Rebuild the project using `v -o flist .`
3. Test your changes thoroughly across different operating systems if possible.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Apache 2.0 License](LICENSE)