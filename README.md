# macOS Printer Package Creator

This repository contains a shell script that automates the creation of macOS packages to install printers. It reads a CSV file with printer information and creates individual packages for each printer, including an option to sign them. Optionally, you can provide printer options as key-value pairs to customize the printer settings.

## Features

- Automatically download printer drivers.
- Remove old printers and add new printers via macOS' CUPS system.
- Sign the package using a specified identity.
- Generate a log file for tracking progress and errors.

## Requirements

- macOS
- curl
- pkgbuild
- Optional: Apple Developer ID for package signing.

## Quick Start

1. Clone this repository:

    ```
    git clone https://github.com/your-username/macOS-Printer-Package-Creator.git
    cd macOS-Printer-Package-Creator
    ```

2. Prepare your `printers.csv` file with the following columns:

    ```
    PkgVersion,OldPrinterName,NewPrinterName,NewPrinterLocation,NewDriverLocation,NewPrinterIP,PackageName,DriverLocation,PrinterOptions
    ```

    For example:

    ```
    1,OldPrinter1,NewPrinter1,Location1,/path/to/driver,ipp://printer1.local,printer-pkg1,https://driver1.zip,option1=value1 option2=value2
    ```

3. Run the script:

    ```
    ./create_printer_pkg.sh
    ```

    If you want to sign the package, use the `--sign` flag followed by the identity:

    ```
    ./create_printer_pkg.sh --sign "Developer ID Installer: Your Name (XXXXXXXXXX)"
    ```

4. The package(s) will be created in the working directory. 

## Customization

If you need to add specific printer options, include them in the last column of your `printers.csv` in the form of `option1=value1 option2=value2`.
