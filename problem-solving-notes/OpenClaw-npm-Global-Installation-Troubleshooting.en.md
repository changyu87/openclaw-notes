# OpenClaw npm Global Installation Troubleshooting

## Introduction
This document addresses common installation issues encountered when using npm (Node Package Manager) for global installations. By understanding these issues, users can resolve errors and successfully install packages.

## Common npm Installation Issues

### EACCES Permission Error
**Description:**  This error occurs when you do not have permission to access the npm global directory.

**Possible Solutions:**
- Change the permissions of the directory:
  ```bash
  sudo chown -R $(whoami) $(npm config get prefix)/{lib/node_modules,bin,share}
  ```
- Alternatively, you can use `npx` to avoid global installations when possible.

### EBADENGINE Node Version Issue
**Description:** This error indicates that the installed version of Node.js does not satisfy the required engine version for the npm package.

**Resolution Steps:**
- Check your current Node version with:
  ```bash
  node -v
  ```
- If it is incompatible, consider using [nvm (Node Version Manager)](https://github.com/nvm-sh/nvm) to install and switch to the appropriate version:
  ```bash
  nvm install <desired-node-version>
  nvm use <desired-node-version>
  ```

### ENOTEMPTY Directory Error
**Description:** This error indicates that the directory is not empty, which is required during certain installation processes.

**Solutions:**
- Remove the contents of the directory before the command:
  ```bash
  rm -rf <directory-path>/*
  ```
- Ensure correct paths and clean any remnants before retrying.

## Final Installation Command
To perform a global installation of a package, use:
```bash
npm install -g <package-name>
```
### Explanation:
- `npm`: Command for Node Package Manager.
- `install`: Action for downloading and installing the package.
- `-g`: Flag indicating a global installation, allowing access from any project.
- `<package-name>`: This is where you specify the name of the package to install.

## Verification Steps
- Verify installation by checking the installed package version:
  ```bash
  npm list -g --depth=0
  ```
- Ensure that the command is recognized:
  ```bash
  <package-command> --version
  ```

## Problem Root Cause Summary Table
| Problem Code   | Description                    | Suggested Fixes                            |
|----------------|--------------------------------|-------------------------------------------|
| EACCES         | Permission denied              | Change directory permissions or use `sudo`|
| EBADENGINE     | Incompatible Node version      | Use `nvm` to change Node version         |
| ENOTEMPTY      | Directory not empty            | Clear directory contents                   |